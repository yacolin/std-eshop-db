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

import pymysql

from seed_data import (BRANDS, CATEGORIES, ATTRS, CATEGORY_PROD_CFG,
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
