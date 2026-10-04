#!/usr/bin/env python3
"""
共享：连接配置、格式常量、DB 连接函数。
被其他 seed_*.py 模块导入。

本文件还提供订单分表（tx_*_YYYYMM）与订单雪花主键的公共辅助：
  - 物理表发现：table_exists / list_tables_like / order_shard_suffixes / order_shard_mode
  - 主键编码：encode_order_id（与 gf-eshop internal/logic/orders/identity.go 同布局）
  - 单号生成：build_business_no + OrderSeqAllocator（每秒序列）
"""
import os
import json
import random
import sys
import argparse
from datetime import datetime, timedelta, timezone

import pymysql

from .seed_data import (BRANDS, CATEGORIES, ATTRS, CATEGORY_PROD_CFG,
                       PRODUCTS_PER_CATEGORY, MERCHANTS, NOTIFICATION_TEMPLATES,
                       COLORS, STORAGES, RAMS, LIPSTICK_SHADES, CLOTHES_SIZES, SHOE_SIZES,
                       PARENT_ORDER_STATUSES, PARENT_ORDER_STATUS_WEIGHTS, SUB_ORDER_STATUS_MAP,
                       USER_LEVEL, POINTS_RULES, LEVEL_RULES,
                       generate_spec, generate_products, _GENERATED_PRODUCTS)

FMT = "%Y-%m-%d %H:%M:%S"

MYSQL_CFG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", 3306)),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", "123456"),
    "database": os.getenv("DB_NAME", "eshop_db"),
    "charset": "utf8mb4",
}


def connect():
    try:
        conn = pymysql.connect(**MYSQL_CFG)
        print("MySQL connected")
        return conn
    except Exception as e:
        print(f"MySQL 连接失败: {e}")
        sys.exit(1)


# ══════════════════════════════════════════════════════════════════════════
# 订单分片 / 雪花主键 公共辅助
#
# 订单域四张表（tx_orders / tx_sub_orders / tx_order_items / tx_order_logs）：
#   * 同键同片 —— 分片键是订单 created_at 的月份，物理表名 tx_orders_202608；
#   * 主键去自增 —— 由应用按「分钟(25)|秒(6)|序列(20)」生成（见 sql/migrations/V001/V002）。
# 布局与 gf-eshop internal/logic/orders/identity.go 保持一致，改动需两边同步。
# ══════════════════════════════════════════════════════════════════════════

#: 需要同键同片维护的四张订单表（逻辑表名）。
ORDER_SHARD_BASES = ("tx_orders", "tx_sub_orders", "tx_order_items", "tx_order_logs")

#: 主键分片/时间位布局：25 + 6 + 20 = 51 位（< 2^53，前端 JS 不丢精度）。
ORDER_ID_SEQ_BITS = 20
ORDER_ID_SECOND_BITS = 6
ORDER_ID_SEQ_MASK = (1 << ORDER_ID_SEQ_BITS) - 1
ORDER_ID_SECOND_MASK = (1 << ORDER_ID_SECOND_BITS) - 1
ORDER_ID_SEQ_MAX = 999999

#: 主键分钟位的起算点（UTC，与 identity.go 的 orderIDEpoch 一致）。
ORDER_ID_EPOCH = datetime(2024, 1, 1, tzinfo=timezone.utc)

#: 小于该值的 id 只可能是迁移前的自增主键（见 identity.go legacyOrderIDMax）。
LEGACY_ORDER_ID_MAX = 1 << 40

#: 业务单号：前缀 + YYYYMMDDHHMMSS(14) + 每秒序列(6)。
ORDER_NO_TIME_FMT = "%Y%m%d%H%M%S"
ORDER_NO_SEQ_DIGITS = 6


def table_exists(cur, name):
    """判断当前库中是否存在某张表。"""
    cur.execute(
        "SELECT COUNT(*) FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s",
        (name,),
    )
    return cur.fetchone()[0] > 0


def list_tables_like(cur, base):
    """列出 base 及其全部物理派生表（月分片 _YYYYMM、归档副本 _legacy_YYYYMM）。"""
    pattern = base.replace("_", "\\_") + "\\_%"
    cur.execute(
        "SELECT TABLE_NAME FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA = DATABASE() AND (TABLE_NAME = %s OR TABLE_NAME LIKE %s) "
        "ORDER BY TABLE_NAME",
        (base, pattern),
    )
    return [row[0] for row in cur.fetchall()]


def order_shard_suffixes(cur):
    """
    返回 tx_orders 的物理布局后缀：'' 表示主表，'202608' 表示月分片。

    `_legacy_YYYYMM`（分表运维工具留下的归档副本）不是活跃分片，不在此列。
    """
    suffixes = []
    for name in list_tables_like(cur, "tx_orders"):
        if name == "tx_orders":
            suffixes.append("")
        elif name.startswith("tx_orders_legacy_"):
            continue
        else:
            suffixes.append(name[len("tx_orders_"):])
    return suffixes


def order_shard_mode(cur):
    """
    探测订单域当前的读写布局，决定 seed 往哪里写：

      single  —— 只有主表（run.sh 基线，尚未分表）
      monthly —— 只有月分片（分表终态；本地演示库即此形态）
      dual    —— 主表与分片并存（灰度双写，两侧写同样的行）
      none    —— 两类表都不存在（还没建表）
    """
    has_base = table_exists(cur, "tx_orders")
    shards = [s for s in order_shard_suffixes(cur) if s]
    if has_base and shards:
        return "dual"
    if has_base:
        return "single"
    if shards:
        return "monthly"
    return "none"


def active_order_suffixes(cur):
    """
    返回读取订单数据时应该使用的**活跃分片后缀**。

    dual（主表 + 分片并存）下分片才是真相源，主表只是过渡期的影子副本 ——
    若两者都读会把同一订单算两遍（积分/评价重复、撞 rev_reviews 唯一键）。
    因此：有月分片就只返回月分片；否则返回 ['']（单表主表）。
    """
    shards = [s for s in order_shard_suffixes(cur) if s]
    return shards if shards else [""]


def active_order_tables(cur, base):
    """按 active_order_suffixes 的语义返回该逻辑表的活跃物理表名列表。"""
    return [physical_table(base, s) for s in active_order_suffixes(cur)
            if table_exists(cur, physical_table(base, s))]


def target_suffixes(mode, moment):
    """给某个时刻的订单返回要写入的物理表后缀列表。"""
    if mode == "single":
        return [""]
    suffix = moment.strftime("%Y%m")
    return ["", suffix] if mode == "dual" else [suffix]


def physical_table(base, suffix):
    """逻辑表名 + 分片后缀 → 物理表名。"""
    return f"{base}_{suffix}" if suffix else base


def shard_template_for(cur, base, exclude):
    """
    返回建分片表时的模板表名，优先级与 gf-eshop shardTemplate 一致：

      主表 base → 同域最新的月分片 → 最新的 legacy 归档副本
      （三者都排除 exclude 自身：`CREATE TABLE x LIKE x` 会报 Not unique table/alias）

    按月分片表名（tx_orders_202608）在字典序上等同月份序，故取升序列表的最后一个即最新月份。
    """
    if base != exclude and table_exists(cur, base):
        return base
    shards = [
        name for name in list_tables_like(cur, base)
        if name != base and name != exclude and f"{base}_legacy_" not in name
    ]
    if shards:
        return shards[-1]
    for name in reversed(list_tables_like(cur, base)):
        if f"{base}_legacy_" in name and name != exclude:
            return name
    raise RuntimeError(
        f"找不到 {base} 的建表模板（主表 / 月分片 / legacy 副本都不存在），"
        f"请先执行 bash run.sh 建出基线表"
    )


def ensure_order_shard_tables(cur, suffix):
    """
    确保某月的四张分片表存在（幂等，结构复制自 shard_template_for）。

    返回本次**实际创建**的物理表名列表（已存在的不会出现在里面）。
    """
    created = []
    for base in ORDER_SHARD_BASES:
        target = physical_table(base, suffix)
        if table_exists(cur, target):
            continue
        template = shard_template_for(cur, base, target)
        cur.execute(f"CREATE TABLE IF NOT EXISTS `{target}` LIKE `{template}`")
        created.append(target)
    return created


def encode_order_id(moment, seq):
    """
    把「时间 + 序列」编成订单域全局唯一主键，与 identity.go encodeOrderID 完全一致：

        minutes << (6 + 20) | second << 20 | seq

    moment 用本地时间（与 created_at / 单号内嵌时间同口径），epoch 用 UTC 起算点。
    """
    minutes = int(moment.timestamp()) // 60 - int(ORDER_ID_EPOCH.timestamp()) // 60
    return (
        minutes << (ORDER_ID_SECOND_BITS + ORDER_ID_SEQ_BITS)
        | (moment.second << ORDER_ID_SEQ_BITS)
        | seq
    )


def build_business_no(prefix, moment, seq):
    """前缀 + YYYYMMDDHHMMSS(14) + 每秒序列(6)，如 ORD20261004130509000001。"""
    return f"{prefix}{moment.strftime(ORDER_NO_TIME_FMT)}{seq:0{ORDER_NO_SEQ_DIGITS}d}"


class OrderSeqAllocator:
    """
    进程内的「每秒序列」分配器，语义等价于 identity.go 的 Redis INCRBY 序列。

    seed 是单进程串行写，不存在多实例竞争；同一秒内多张单/多个单号拿到互不重叠的序列段。
    """

    def __init__(self, label="order"):
        self._by_second = {}
        self._label = label

    def allocate(self, moment, need):
        """为 moment 所在秒分配 need 个连续序列，返回段首。"""
        key = moment.strftime(ORDER_NO_TIME_FMT)
        start = self._by_second.get(key, 0) + 1
        if start < 1 or start + need - 1 > ORDER_ID_SEQ_MAX:
            raise RuntimeError(
                f"{self._label} 在 {key} 这一秒的序列已用尽（start={start}, need={need}）"
            )
        self._by_second[key] = start + need - 1
        return start


def insert_sharded(cur, mode, base, moment, columns, values):
    """
    按当前布局把一行写进订单域逻辑表 base：

      single  → 只写主表；monthly → 只写当月分片；dual → 两侧各写一份。
    列名/占位符由调用方给出，保证两侧结构完全一致。
    """
    columns_sql = ", ".join(f"`{c}`" for c in columns)
    placeholders = ", ".join(["%s"] * len(columns))
    for suffix in target_suffixes(mode, moment):
        table = physical_table(base, suffix)
        cur.execute(
            f"INSERT INTO `{table}` ({columns_sql}) VALUES ({placeholders})", values
        )


def truncate_if_exists(cur, name):
    """表存在才 TRUNCATE —— 分表后主表可能已归档，硬编码表名会直接报 Error 1146。"""
    if table_exists(cur, name):
        cur.execute(f"TRUNCATE TABLE `{name}`")
        return True
    return False


def drop_order_baseline_tables(cur):
    """
    删除基线的 4 张订单主表，回到「只有月分片」的分表终态（monthly）。

    dual（主表 + 分片并存）下主表只是过渡镜像：应用跑 monthly 时读写的是分片，
    主表会逐渐过期，留着容易被误读。**仅当存在月分片时**才删（否则库就是单表形态，
    删了主表等于把数据删没）。返回被删除的表名列表。
    """
    if not [s for s in order_shard_suffixes(cur) if s]:
        return []
    dropped = []
    for base in ORDER_SHARD_BASES:
        if table_exists(cur, base):
            cur.execute(f"DROP TABLE `{base}`")
            dropped.append(base)
    return dropped
