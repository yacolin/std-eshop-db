#!/usr/bin/env python3
"""
schema_diff.py — schema 变更对比（P2 Schema diff）

用法（仓库根目录）：
    python3 tools/schema_diff.py                      # 工作区 vs HEAD（git）双库
    python3 tools/schema_diff.py --base 7a2d5e0       # 指定对比基线 commit
    python3 tools/schema_diff.py --engine mysql       # 只对比 MySQL
    python3 tools/schema_diff.py --summary            # 仅摘要

输出：表/列/索引/CHECK 的新增、删除、修改；含 -- DESTRUCTIVE 标记提示。

无第三方依赖；对比对象是 sql/*.sql（mysql）与 pgsql/*.sql（pg）的静态 CREATE TABLE。
"""
import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def read_from_git(ref: str, engine: str) -> dict:
    """读取某 commit 下某引擎全部 *.sql 的文本（不含 00_/run/audit）。"""
    folder = 'sql' if engine == 'mysql' else 'pgsql'
    out = {}
    # 用 git ls-tree 取文件清单再逐个读
    names = subprocess.check_output(
        ['git', 'ls-tree', '--name-only', '-r', ref, '--', folder],
        cwd=ROOT, text=True).splitlines()
    for rel in names:
        base = pathlib.PurePosixPath(rel).name
        if base.startswith(('00_', '01_', '02_', '03_', '04_', '05_')) or base == 'run.sql':
            continue
        if base.endswith('.sql'):
            content = subprocess.check_output(
                ['git', 'show', f'{ref}:{rel}'], cwd=ROOT, text=True)
            out[base] = content
    return out


def read_worktree(engine: str) -> dict:
    folder = 'sql' if engine == 'mysql' else 'pgsql'
    out = {}
    for p in sorted((ROOT / folder).glob('*.sql')):
        if p.name.startswith(('00_', '01_', '02_', '03_', '04_', '05_')) or p.name == 'run.sql':
            continue
        out[p.name] = p.read_text(encoding='utf-8')
    return out


TBL = re.compile(r'CREATE TABLE\s+`?(\w+)`?\s*\((.*?)\)\s*(?:ENGINE\s*=|;|PARTITION)', re.S | re.I)
COL = re.compile(r'^\s*`?(\w+)`?\s+([a-z0-9_]+(?:\([^)]*\))?)\s*(.*)$', re.I)
KEY = re.compile(r'^\s*(?:UNIQUE\s+(?:KEY\s+)?|KEY\s+|INDEX\s+|PRIMARY\s+KEY\s+|CONSTRAINT\s+`?(\w+)`?\s+(CHECK|UNIQUE)\b)(.*)$', re.I)


def parse(text: str):
    """返回 {表: {'cols': {col: sig}, 'keys': set, 'checks': set}}。"""
    schema = {}
    for m in TBL.finditer(text):
        tname, body = m.group(1), m.group(2)
        cols, keys, checks = {}, set(), set()
        for raw in body.splitlines():
            line = raw.strip()
            if not line or line.startswith('--'):
                continue
            cm = COL.match(line)
            if cm and not line.lower().startswith(('unique', 'key', 'index', 'primary', 'constraint', 'check')):
                cols[cm.group(1)] = re.sub(r'\s+', ' ', line.lower())
                continue
            km = KEY.match(line)
            if km:
                sig = re.sub(r'\s+', ' ', line.lower())
                if km.group(2) == 'CHECK':
                    checks.add(sig)
                else:
                    keys.add(sig)
        schema[tname] = {'cols': cols, 'keys': keys, 'checks': checks}
    return schema


def diff_engine(base_files, new_files, label):
    print(f'\n===== {label} =====')
    old = {}
    for name, text in base_files.items():
        old.update(parse(text))
    new = {}
    for name, text in new_files.items():
        new.update(parse(text))
    for tname in sorted(set(old) | set(new)):
        if tname not in old:
            print(f'  + 表 {tname}')
            continue
        if tname not in new:
            print(f'  - 表 {tname}  (DESTRUCTIVE: 删除表)')
            continue
        o, n = old[tname], new[tname]
        for c in sorted(set(o['cols']) | set(n['cols'])):
            if c not in o['cols']:
                print(f'  + {tname}.{c} 新增列')
            elif c not in n['cols']:
                print(f'  - {tname}.{c} 删除列 (DESTRUCTIVE: 删列/数据丢失风险)')
            elif o['cols'][c] != n['cols'][c]:
                print(f'  ~ {tname}.{c} 列定义变化')
        for k in sorted(o['keys'] - n['keys']):
            print(f'  - {tname} 索引/唯一键移除: {k[:80]}')
        for k in sorted(n['keys'] - o['keys']):
            print(f'  + {tname} 索引/唯一键新增: {k[:80]}')
        for c in sorted(o['checks'] - n['checks']):
            print(f'  - {tname} CHECK 移除: {c[:100]}')
        for c in sorted(n['checks'] - o['checks']):
            print(f'  + {tname} CHECK 新增: {c[:100]}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--base', default='HEAD', help='对比基线 git ref（默认 HEAD）')
    ap.add_argument('--engine', choices=['mysql', 'pg', 'all'], default='all')
    ap.add_argument('--summary', action='store_true')
    args = ap.parse_args()

    for engine, label in (('mysql', 'MySQL sql/'), ('pg', 'PostgreSQL pgsql/')):
        if args.engine != 'all' and args.engine != engine:
            continue
        base = read_from_git(args.base, engine)
        new = read_worktree(engine)
        # 只保留两侧都有或新增的文件；删除文件视为全部表删除
        diff_engine(base, new, label)


if __name__ == '__main__':
    main()
