#!/usr/bin/env python3
"""
sql_lint.py — 电商数据库 SQL 静态检查（P2 SQL lint / CI 可复用）

用法（仓库根目录）：
    python3 tools/sql_lint.py            # 检查 sql/ 与 pgsql/ 全量 DDL
    python3 tools/sql_lint.py --engine mysql   # 只查 MySQL
    python3 tools/sql_lint.py --engine pg      # 只查 PostgreSQL

检查规则（详见 sql/P2_SQLlint规范.md）：
  R1 全库禁止 FOREIGN KEY / REFERENCES（逻辑外键、应用自治）
  R2 金额列必须是 bigint 分、NOT NULL，且所在表有引用该列的非负/正数 CHECK
  R3 CHECK 约束名不重复（MySQL 要求库内唯一）
  R4 同表内不允许重复索引（同列集合）
  R5 常规建表文件禁止出现 DROP TABLE / TRUNCATE（只允许在 00_drop_tables.sql）
  R6 状态/枚举列必须带 COMMENT（MySQL）或独立 COMMENT（PG 可选，宽松）
  R7 禁止将空串默认值列直接放入 UNIQUE 键（需 NULL 归一，如 xx_uq 生成列）

退出码：0 = 通过；1 = 有违规；2 = 用法错误。
"""
import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

MONEY_COLS = {
    # 表: {列: 语义}  —— 权威清单见 sql/P0_金额审计清单.md §1
    'tx_orders': ['total_amount', 'discount_amount', 'shipping_fee', 'pay_amount'],
    'tx_sub_orders': ['total_amount', 'discount_amount', 'shipping_fee', 'pay_amount'],
    'tx_order_items': ['price', 'subtotal', 'refund_amount'],
    'tx_order_daily_stats': ['gmv', 'paid_amount', 'refund_amount'],
    'tx_cart_items': ['price'],
    'tx_payments': ['amount'],
    'tx_refunds': ['amount'],
    'tx_after_sales': ['amount'],
    'tx_deliveries': ['shipping_fee'],
    'sp_skus': ['price', 'market_price', 'cost_price'],
    'mch_merchants': ['total_sales'],
    'mch_merchant_balances': ['available_balance', 'freeze_balance'],
    'mch_merchant_withdrawals': ['amount'],
    'mch_merchant_settlement_logs': ['total_amount', 'commission_amount', 'settlement_amount'],
    'mch_settlement_details': ['order_amount', 'commission_amount', 'settlement_amount', 'refund_amount'],
    'mkt_promotion_usage_logs': ['discount_amount'],
}

FUND_TABLES = {'tx_payments', 'tx_refunds', 'mch_merchant_balances',
               'mch_merchant_withdrawals', 'mch_merchant_settlement_logs',
               'mch_settlement_details'}  # 资金表只可追加：禁止 deleted_at（P1）


def extract_tables(text):
    """解析 CREATE TABLE 块，返回 {表名: (列定义行列表, 约束文本, 块文本)}。"""
    tables = {}
    # 兼容 mysql(`) 与 pg
    pat = re.compile(
        r"CREATE TABLE\s+`?(\w+)`?\s*\((.*?)\)\s*(?:ENGINE\s*=|;|PARTITION)",
        re.S | re.I)
    for m in pat.finditer(text):
        tables[m.group(1)] = m.group(2)
    return tables


def lint_engine(engine):
    d = ROOT / ('sql' if engine == 'mysql' else 'pgsql')
    files = sorted(d.glob('*.sql'))
    combined = '\n'.join(p.read_text(encoding='utf-8') for p in files)
    issues = []

    # R1 no FK
    if re.search(r'\bFOREIGN\s+KEY\b|\bREFERENCES\b', combined, re.I):
        for p in files:
            for i, line in enumerate(p.read_text(encoding='utf-8').splitlines(), 1):
                if re.search(r'\bFOREIGN\s+KEY\b|\bREFERENCES\b', line, re.I):
                    issues.append(f'[R1] {p.name}:{i} 禁止 FOREIGN KEY/REFERENCES（逻辑外键）')

    # R2 money col bigint+NOT NULL + check 覆盖
    for f in files:
        if f.name.startswith(('00_', '01_', '02_', '03_', '04_', '05_')) or f.name == 'run.sql':
            continue
        text = f.read_text(encoding='utf-8')
        tables = extract_tables(text)
        for tname, body in tables.items():
            money = MONEY_COLS.get(tname)
            if not money:
                continue
            low = body.lower()
            for col in money:
                cm = re.search(rf'`?{col}`?\s+((?:bigint|money_amount|positive_money)\b)', body, re.I)
                if cm is None:
                    issues.append(f'[R2] {f.name}: {tname}.{col} 应为 bigint(分)/money DOMAIN')
                    continue
                col_decl = re.search(rf'`?{col}`?\s+[a-z0-9_]+(?:\([^)]*\))?[^\n,]*', body, re.I)
                if col_decl and 'not null' not in col_decl.group(0).lower():
                    issues.append(f'[R2] {f.name}: {tname}.{col} 应 NOT NULL')
                # 表级 CHECK 必须引用该列且含 >=/>/BETWEEN（body 已 lower）
                if not re.search(rf'check\s*\([^)]*`?{col}`?[^)]*(>=|>|between)', low):
                    issues.append(f'[R2] {f.name}: {tname}.{col} 缺非负/正数 CHECK')

    # R3 duplicate check names (MySQL schema-wide; PG per-table)
    check_names = {}
    for f in files:
        text = f.read_text(encoding='utf-8')
        for tname, body in extract_tables(text).items():
            for cm in re.finditer(r'CONSTRAINT\s+`?(\w+)`?\s+CHECK', body, re.I):
                name = cm.group(1)
                check_names.setdefault(name, []).append(f'{f.name}:{tname}')
    for name, locs in check_names.items():
        if len(set(locs)) > 1:
            issues.append(f'[R3] CHECK 约束名重复: {name} -> {locs}')

    # R4 duplicate indexes per table
    for f in files:
        text = f.read_text(encoding='utf-8')
        for tname, body in extract_tables(text).items():
            seen = {}
            for km in re.finditer(r'(?:UNIQUE\s+(?:KEY\s+)?|KEY\s+|INDEX\s+)(?:`?(\w+)`?\s*)?\(([^)]*)\)', body, re.I):
                idxname = km.group(1) or ''
                cols = re.sub(r'\s+', '', km.group(2).lower())
                if idxname == 'primary' or cols.startswith('(`id`)'):
                    continue
                if cols in seen:
                    issues.append(f'[R4] {f.name}: {tname} 重复索引列集合 {cols}（{seen[cols]} 与 {idxname}）')
                else:
                    seen[cols] = idxname or '(anonymous)'

    # R5 DROP/TRUNCATE only in 00_drop_tables.sql
    for f in files:
        if f.name in ('00_drop_tables.sql', 'run.sql'):
            continue
        for i, line in enumerate(f.read_text(encoding='utf-8').splitlines(), 1):
            if re.search(r'^\s*DROP\s+TABLE|^\s*TRUNCATE\s+TABLE', line, re.I):
                issues.append(f'[R5] {f.name}:{i} 常规建表文件禁止 DROP/TRUNCATE')

    # R6 status/enum columns need comment (MySQL 强制注释；PG 文件内 COMMENT 已分散，宽松跳过)
    if engine == 'mysql':
        for f in files:
            text = f.read_text(encoding='utf-8')
            for tname, body in extract_tables(text).items():
                for line in body.splitlines():
                    cm = re.search(r'`(\w+)`\s+(varchar\(20\)|tinyint|smallint|int|char)\b', line, re.I)
                    if not cm:
                        continue
                    col = cm.group(1)
                    if re.search(r'status|type|method|channel|level|source|scope|category', col, re.I):
                        if 'COMMENT' not in line.upper():
                            issues.append(f'[R6] {f.name}: {tname}.{col} 状态/枚举列需注释取值')

    # R7 empty-string default under UNIQUE
    for f in files:
        text = f.read_text(encoding='utf-8')
        for tname, body in extract_tables(text).items():
            low = body.lower()
            uniq_cols = set()
            for um in re.finditer(r'UNIQUE\s+(?:KEY\s+)?`?(\w+)`?\s*\(([^)]*)\)', body, re.I):
                for c in re.findall(r'`?(\w+)`?', um.group(2)):
                    uniq_cols.add(c.lower())
            for cm in re.finditer(r'`(\w+)`\s+[a-z0-9_]+\([^)]*\)\s+NOT NULL DEFAULT \'\'', body, re.I):
                if cm.group(1).lower() in uniq_cols:
                    issues.append(f'[R7] {f.name}: {tname}.{cm.group(1)} 空串默认值参与唯一键，需 NULL 归一')

    # 资金表禁止 deleted_at（P1）
    for f in files:
        text = f.read_text(encoding='utf-8')
        for tname, body in extract_tables(text).items():
            if tname in FUND_TABLES and re.search(r'deleted_at', body, re.I):
                issues.append(f'[P1] {f.name}: {tname} 资金表禁止 deleted_at（只可追加）')

    return issues


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--engine', choices=['mysql', 'pg', 'all'], default='all')
    args = ap.parse_args()
    engines = ['mysql', 'pg'] if args.engine == 'all' else [args.engine]
    all_issues = []
    for e in engines:
        label = 'MySQL sql/' if e == 'mysql' else 'PostgreSQL pgsql/'
        print(f'--- 检查 {label}---')
        iss = lint_engine(e)
        for i in iss:
            print(f'  ✗ {i}')
        all_issues += iss
    if all_issues:
        print(f'\n共 {len(all_issues)} 处违规')
        return 1
    print('\nSQL lint 通过 ✅')
    return 0


if __name__ == '__main__':
    sys.exit(main())
