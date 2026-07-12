#!/usr/bin/env python3
"""
共享：连接配置、格式常量、DB 连接函数。
被其他 seed_*.py 模块导入。
"""
import os
import json
import random
import sys
import argparse
from datetime import datetime, timedelta

import psycopg2

from seed_data import (BRANDS, CATEGORIES, ATTRS, CATEGORY_PROD_CFG,
                       PRODUCTS_PER_CATEGORY, MERCHANTS, NOTIFICATION_TEMPLATES,
                       COLORS, STORAGES, RAMS, LIPSTICK_SHADES, CLOTHES_SIZES, SHOE_SIZES,
                       PARENT_ORDER_STATUSES, PARENT_ORDER_STATUS_WEIGHTS, SUB_ORDER_STATUS_MAP,
                       USER_LEVEL, POINTS_RULES, LEVEL_RULES,
                       generate_spec, generate_products, _GENERATED_PRODUCTS)

FMT = "%Y-%m-%d %H:%M:%S"

PG_CFG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", 5432)),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "postgres"),
    "dbname": os.getenv("DB_NAME", "eshop_db"),
}


def connect():
    try:
        conn = psycopg2.connect(**PG_CFG)
        conn.autocommit = False
        print("PostgreSQL connected")
        return conn
    except Exception as e:
        print(f"PostgreSQL 连接失败: {e}")
        sys.exit(1)
