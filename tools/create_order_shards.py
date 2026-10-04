#!/usr/bin/env python3
"""
create_order_shards.py — 直接在数据库创建订单月分片表（等价 gf-eshop `shard --action=create`）

用途：服务器上不方便/不想跑 gf-eshop CLI 时，用本工具把
tx_orders_YYYYMM / tx_sub_orders_YYYYMM / tx_order_items_YYYYMM / tx_order_logs_YYYYMM 建出来。

用法（仓库根目录）：
    python3 tools/create_order_shards.py --from 2026-07 --to 2026-10
    python3 tools/create_order_shards.py --from 2026-07 --to 2026-10 --dry-run

连库参数走环境变量（与 seed 共用）：DB_HOST / DB_PORT / DB_USER / DB_PASSWORD / DB_NAME。
服务器上可直接指向 RDS，不必启动应用：

    DB_HOST=<RDS内网地址> DB_USER=<应用账号> DB_PASSWORD=<密码> DB_NAME=eshop_db \
        python3 tools/create_order_shards.py --from 2026-07 --to 2026-10

行为与约束
- 幂等：已存在的分片跳过（`CREATE TABLE IF NOT EXISTS ... LIKE`），中断可重跑。
- 模板优先级与 gf-eshop shardTemplate 一致：主表 → 该域最新月分片 → 最新 legacy 副本；
  因此库里至少要有一张订单基线表（`run.sh` 建出）或已有分片。
- `--from/--to` 收 `2026-07` 或 `202607`，闭区间；月份是执行期参数，**不写进基线**。
- **只建表、不搬数据**：历史数据迁移请用 gf-eshop 的 `shard --action=migrate`
  （它还负责登记 tx_order_shard_map、回填 tx_order_daily_stats、三重对账），本工具不碰这些。
- 分片表是**应用管理的动态对象、不入基线**（见 `sql/tx_p5.sql` 头注释）。本工具是运维兜底：
  monthly 模式下跨月后的第一笔订单写入会自动建当月分片，正常不需要手工执行。
- 别一次建太多空月份：订单列表/看板是跨片 fan-out（gf-eshop `activeShards()` 枚举全部
  `tx_orders_%`），空分片也会被扫到。建「有数据的月份 + 当月」即可。

退出码：0 = 完成；1 = 执行失败；2 = 用法/连接错误。
"""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sql.seed.seed_common import (  # noqa: E402
    connect, ORDER_SHARD_BASES, order_shard_mode, physical_table,
    table_exists, shard_template_for, ensure_order_shard_tables,
)


def parse_month(value):
    """`2026-07` / `202607` → `202607`。"""
    text = value.strip().replace("-", "")
    if len(text) != 6 or not text.isdigit():
        raise ValueError(f"月份 {value!r} 格式非法，应为 2026-07 或 202607")
    if not 1 <= int(text[4:]) <= 12:
        raise ValueError(f"月份 {value!r} 的月份位非法（01~12）")
    return text


def month_range(start, end):
    """返回 [start, end] 闭区间内的所有 YYYYMM。"""
    year, month = int(start[:4]), int(start[4:])
    end_year, end_month = int(end[:4]), int(end[4:])
    if (year, month) > (end_year, end_month):
        raise ValueError(f"起始月份 {start} 晚于结束月份 {end}")
    months = []
    while (year, month) <= (end_year, end_month):
        months.append(f"{year:04d}{month:02d}")
        month += 1
        if month > 12:
            year, month = year + 1, 1
    return months


def main():
    parser = argparse.ArgumentParser(
        description="在数据库里创建订单月分片表（等价 gf-eshop shard --action=create）")
    parser.add_argument("--from", dest="month_from", required=True, metavar="YYYY-MM",
                        help="起始月份，闭区间，如 2026-07")
    parser.add_argument("--to", dest="month_to", required=True, metavar="YYYY-MM",
                        help="结束月份，闭区间，如 2026-10")
    parser.add_argument("--dry-run", action="store_true",
                        help="只列出将要创建的表，不执行 DDL（不需要 CREATE 权限）")
    args = parser.parse_args()

    try:
        months = month_range(parse_month(args.month_from), parse_month(args.month_to))
    except ValueError as exc:
        print(f"参数错误：{exc}")
        return 2

    conn = connect()
    cur = conn.cursor()
    mode_before = order_shard_mode(cur)
    print(f"当前布局: {mode_before}（目标月份: {' '.join(months)}）")

    try:
        if args.dry_run:
            planned = []
            for ym in months:
                for base in ORDER_SHARD_BASES:
                    target = physical_table(base, ym)
                    if table_exists(cur, target):
                        continue
                    planned.append((target, shard_template_for(cur, base, target)))
            if not planned:
                print("目标分片表都已存在，无需创建")
            else:
                for target, template in planned:
                    print(f"[dry-run] 将创建 {target}（模板 {template}）")
                print(f"[dry-run] 共 {len(planned)} 张表")
            return 0

        created = []
        for ym in months:
            created += ensure_order_shard_tables(cur, ym)
        conn.commit()
    except Exception as exc:  # RuntimeError（找不到模板）或 pymysql 错误
        print(f"建分片失败：{exc}")
        return 1

    if created:
        for name in created:
            print(f"已创建 {name}")
    else:
        print("目标分片表都已存在，无需创建")
    print(f"完成：新建 {len(created)} 张 / 目标 {len(months) * len(ORDER_SHARD_BASES)} 张")

    mode_after = order_shard_mode(cur)
    if mode_after != mode_before:
        print(f"布局变化: {mode_before} → {mode_after}")
    if mode_before == "single" and created:
        print("提示：库里原本只有主表（single），现在主表与分片并存（dual）。"
              "若应用要切 monthly 且历史数据要保留，"
              "请先用 gf-eshop `shard --action=migrate` 把主表数据搬进分片，再改 orderShard.mode。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
