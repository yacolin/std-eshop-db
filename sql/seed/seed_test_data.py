#!/usr/bin/env python3
"""
测试种子数据入口 — 导入各域模块并统一编排。

用法（在仓库根目录执行）：
    python -m sql.seed.seed_test_data                   # 生成全部
    python -m sql.seed.seed_test_data --clean           # 先清空再生成
    python -m sql.seed.seed_test_data --module product  # 只生成商品域
    python -m sql.seed.seed_test_data --clean --sharded-only
                                          # 生成后删掉基线订单主表，回到「只有月分片」的分表终态
"""
import argparse

from .seed_common import (connect, ORDER_SHARD_BASES, active_order_tables,
                          drop_order_baseline_tables, order_shard_suffixes)
from .seed_clean import clean
from .seed_product import seed_product
from .seed_inventory import seed_inventory
from .seed_marketing import seed_marketing
from .seed_notification import seed_notification
from .seed_merchant import seed_merchant
from .seed_users import seed_users
from .seed_departments import seed_departments
from .seed_level import seed_level
from .seed_order import seed_order
from .seed_points import seed_points, seed_points_rules, seed_level_rules
from .seed_review import seed_review


def main():
    parser = argparse.ArgumentParser(description="为新表生成测试数据")
    parser.add_argument("--clean", action="store_true", help="先清空再生成")
    parser.add_argument("--sharded-only", dest="sharded_only", action="store_true",
                        help="生成后删除基线订单主表（仅当已存在月分片），回到「只有月分片」的分表终态")
    parser.add_argument("--module", choices=["product", "inventory", "marketing", "merchant",
                                              "users", "departments", "level", "order", "notification",
                                              "points", "points_rules", "level_rules", "review"],
                        help="只生成指定模块")
    args = parser.parse_args()

    conn = connect()
    if args.clean:
        clean(conn)

    modules = {
        "merchant": seed_merchant,
        "product": seed_product,
        "inventory": seed_inventory,
        "marketing": seed_marketing,
        "notification": seed_notification,
        "users": seed_users,
        "departments": seed_departments,
        "level": seed_level,
        "order": seed_order,
        "points": seed_points,
        "points_rules": seed_points_rules,
        "level_rules": seed_level_rules,
        "review": seed_review,
    }

    if args.module:
        if args.module in modules:
            modules[args.module](conn)
        else:
            print(f"未知模块: {args.module}")
    else:
        for name, fn in modules.items():
            print(f"正在生成: {name}")
            fn(conn)

    with conn.cursor() as cur:
        for table in ["sp_brands", "sp_categories", "sp_attributes", "sp_products",
                      "sp_skus", "sp_attribute_values", "sp_sku_specs",
                      "sp_product_descriptions", "sp_product_attributes",
                      "sp_category_attributes",
                      "sp_inventories", "mkt_promotions", "mkt_promotion_stocks", "mkt_user_promotions",
                      "tx_payments", "tx_refunds",
                      "tx_deliveries", "usr_addresses", "usr_levels", "usr_points", "usr_points_rules", "usr_level_rules",
                      "mch_merchants", "mch_merchant_balances",
                      "base_notification_templates",
                      "rev_reviews", "rev_review_media", "rev_review_replies", "rev_review_audit_logs",
                      "rev_review_statistics", "rev_review_usefulness"]:
            cur.execute(f"SELECT COUNT(*) AS cnt FROM {table}")
            row = cur.fetchone()
            print(f"  {table}: {row[0]}")

        # 订单域四张表：分表后跨月分片汇总；dual（主表+分片）下只统计活跃分片，避免重复计数
        for base in ORDER_SHARD_BASES:
            total = 0
            for name in active_order_tables(cur, base):
                cur.execute(f"SELECT COUNT(*) FROM `{name}`")
                total += cur.fetchone()[0]
            print(f"  {base}: {total}")

    if args.sharded_only:
        with conn.cursor() as cur:
            has_shards = bool([s for s in order_shard_suffixes(cur) if s])
            dropped = drop_order_baseline_tables(cur)
        conn.commit()
        if dropped:
            print(f"\n--sharded-only：已删除基线订单主表 {', '.join(dropped)}，当前回到 monthly 分表终态")
        elif has_shards:
            print("\n--sharded-only：当前已是「只有月分片」的分表终态，无需处理")
        else:
            print("\n--sharded-only：库中没有月分片，未删主表（单表形态下删主表会丢数据）")

    conn.close()
    print("\n完成!")


if __name__ == "__main__":
    main()
