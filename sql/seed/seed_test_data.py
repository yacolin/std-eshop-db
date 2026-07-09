#!/usr/bin/env python3
"""
测试种子数据生成器 — 导入 seed_data 中的常量 + 生成函数，并执行 DB 插入。

用法：
    python sql/seed/seed_test_data.py                   # 生成全部
    python sql/seed/seed_test_data.py --clean            # 先清空再生成
    python sql/seed/seed_test_data.py --module product   # 只生成商品域

依赖：
    pip install pymysql
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


# ── 连接 / 清空 ────────────────────────────────

def connect():
    try:
        conn = pymysql.connect(**MYSQL_CFG)
        print("MySQL connected")
        return conn
    except Exception as e:
        print(f"MySQL 连接失败: {e}")
        sys.exit(1)


def clean(conn):
    tables = [
        "mch_settlement_details", "mch_merchant_settlement_logs", "mch_merchant_withdrawals",
        "mch_merchant_balances", "mch_merchant_users", "mch_merchant_qualifications",
        "mch_merchant_bank_accounts", "mch_merchant_contacts", "mch_merchants",
        "mkt_promotion_usage_logs", "mkt_user_promotions", "mkt_promotion_products",
        "mkt_promotion_rules", "mkt_promotions", "mkt_promotion_stocks",
        "tx_refunds", "tx_payment_logs", "tx_payments",
        "tx_order_logs", "tx_order_items", "tx_orders", "tx_sub_orders",
        "tx_cart_items", "tx_carts",
        "tx_after_sale_evidences", "tx_after_sale_logs", "tx_after_sales",
        "sp_inventory_logs", "sp_inventories", "sp_product_versions",
        "sp_product_attributes", "sp_product_descriptions", "sp_sku_specs",
        "sp_attribute_values", "sp_skus",
        "sp_products", "sp_attributes", "sp_category_brands", "sp_categories", "sp_brands",
        "mch_merchant_role_permissions", "mch_merchant_roles",
        "sys_staff_departments", "sys_departments",
        "usr_addresses", "usr_points", "usr_points_rules", "usr_levels", "usr_level_rules",
        "tx_delivery_traces", "tx_delivery_items", "tx_deliveries",
        "base_notification_reads", "base_notifications", "base_notification_templates",
        "rev_review_usefulness", "rev_review_statistics",
        "rev_review_audit_logs", "rev_review_replies", "rev_review_media", "rev_reviews",
    ]
    with conn.cursor() as cur:
        cur.execute("SET FOREIGN_KEY_CHECKS = 0")
        for t in tables:
            cur.execute(f"TRUNCATE TABLE {t}")
        cur.execute("SET FOREIGN_KEY_CHECKS = 1")
    conn.commit()
    print("已清空所有新表\n")


# ── 商品中心 ──────────────────────────────────────

def seed_product(conn):
    global _GENERATED_PRODUCTS
    if _GENERATED_PRODUCTS is None:
        _GENERATED_PRODUCTS = generate_products()
        print(f"  自动生成 SPU: {len(_GENERATED_PRODUCTS)} 个")
    products = _GENERATED_PRODUCTS

    with conn.cursor() as cur:
        # 获取已 seeded 的商家 ID
        cur.execute("SELECT id FROM mch_merchants WHERE deleted_at IS NULL ORDER BY id")
        merchant_ids = [row[0] for row in cur.fetchall()]
        if not merchant_ids:
            print("  ⚠ 无商家数据，商品将绑定 merchant_id=0")
            merchant_ids = [0]
        brand_id_map = {}
        for name, cname, letter in BRANDS:
            cur.execute(
                "INSERT INTO sp_brands (name, english_name, first_letter, sort_order, status) "
                "VALUES (%s, %s, %s, %s, 1)",
                (cname, name, letter, random.randint(1, 100)),
            )
            brand_id_map[(cname, name)] = cur.lastrowid
        print(f"  品牌: {len(BRANDS)}")

        cat_ids = {}
        for i, (parent_id, name, level) in enumerate(CATEGORIES, 1):
            path = ""
            if parent_id > 0:
                parent_id_actual = cat_ids.get(parent_id)
                if parent_id_actual:
                    cur.execute("SELECT path FROM sp_categories WHERE id = %s", (parent_id_actual,))
                    row = cur.fetchone()
                    if row:
                        path = row[0] + str(parent_id_actual) + "/"
            cur.execute(
                "INSERT INTO sp_categories (name, parent_id, level, path, sort_order, status) "
                "VALUES (%s, %s, %s, %s, %s, 1)",
                (name, parent_id if parent_id == 0 else cat_ids.get(parent_id, 0), level, path, i * 10),
            )
            cat_ids[i] = cur.lastrowid
        print(f"  类目: {len(CATEGORIES)}")

        attr_map = {}
        for cat_idx, name, input_type, values, is_sku, searchable in ATTRS:
            filterable = 1 if values else 0
            cur.execute(
                "INSERT INTO sp_attributes (name, category_id, value_type, filterable, is_sku_spec, searchable, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, 1)",
                (name, cat_ids[cat_idx], input_type, filterable, is_sku, searchable),
            )
            attr_id = cur.lastrowid
            attr_map[(cat_idx, name)] = attr_id
            if values:
                for sort_order, v in enumerate(json.loads(values)):
                    cur.execute(
                        "INSERT INTO sp_attribute_values (attribute_id, `value`, sort_order, status) "
                        "VALUES (%s, %s, %s, 1)",
                        (attr_id, v, sort_order),
                    )
        print(f"  属性: {len(ATTRS)}")

        total_skus = 0
        product_count = 0
        for name, subtitle, cat_idx, brand_idx, price, market, unit in products:
            brand_id = brand_idx
            merchant_id = random.choice(merchant_ids)
            cur.execute(
                "INSERT INTO sp_products (merchant_id, name, subtitle, category_id, brand_id, unit, main_image, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, '', 2)",
                (merchant_id, name, subtitle, cat_ids[cat_idx], brand_id, unit),
            )
            spu_id = cur.lastrowid
            product_count += 1

            sku_count = random.randint(2, 6)
            generated_specs = set()
            for j in range(sku_count):
                spec_json, spec_dict = generate_spec(cat_idx)
                if spec_json in generated_specs:
                    color = random.choice(COLORS[:8])
                    if "颜色" in spec_dict:
                        spec_dict["颜色"] = color
                    spec_json = '{"' + '","'.join([f'{k}":"{v}' for k, v in spec_dict.items()]) + '"}'
                    if spec_json in generated_specs:
                        continue
                generated_specs.add(spec_json)

                sku_price = price + random.randint(-int(price * 0.2), int(price * 0.3))
                sku_price = max(price - int(price * 0.3), sku_price)
                sku_code = f"SKU{spu_id}-{j+1:03d}"
                barcode = f"{random.randint(1000000000000, 9999999999999)}"
                spec_dict = json.loads(spec_json)
                spec_summary = " / ".join(str(v) for v in spec_dict.values())
                cur.execute(
                    "INSERT INTO sp_skus (product_id, merchant_id, sku_code, barcode, spec_summary, price, market_price, cost_price, status) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 1)",
                    (spu_id, merchant_id, sku_code, barcode, spec_summary, sku_price,
                     sku_price + random.randint(int(sku_price * 0.1), int(sku_price * 0.3)),
                     int(sku_price * 0.6)),
                )
                sku_id = cur.lastrowid
                # 写入 sp_sku_specs（EAV 规格映射）
                sort_order = 0
                for spec_name, spec_value in spec_dict.items():
                    spec_attr_id = attr_map.get((cat_idx, spec_name))
                    if spec_attr_id is None:
                        continue
                    cur.execute(
                        "SELECT id FROM sp_attribute_values WHERE attribute_id = %s AND `value` = %s",
                        (spec_attr_id, spec_value),
                    )
                    row = cur.fetchone()
                    if row:
                        cur.execute(
                            "INSERT INTO sp_sku_specs (sku_id, attribute_id, attribute_value_id, sort_order) "
                            "VALUES (%s, %s, %s, %s)",
                            (sku_id, spec_attr_id, row[0], sort_order),
                        )
                        sort_order += 1
                total_skus += 1

            has_desc = 0
            if random.random() < 0.7:
                desc_text = f"{name}是一款优质的{subtitle}产品，给您带来极致体验。采用高品质材料，精心打造每一个细节。"
                mobile_text = f"<h1>{name}</h1><p>{subtitle}，{desc_text}</p>"
                cur.execute(
                    "INSERT INTO sp_product_descriptions (product_id, description, mobile_description) "
                    "VALUES (%s, %s, %s)",
                    (spu_id, desc_text, mobile_text),
                )
                has_desc = 1
            if has_desc == 1:
                cur.execute("UPDATE sp_products SET has_description = 1 WHERE id = %s", (spu_id,))

            for (a_cat_idx, attr_name), attr_id in attr_map.items():
                if a_cat_idx == cat_idx:
                    val = random.choice(["标准", "优质", "普通", "高级", "入门"])
                    if attr_name in ["颜色", "色号"]:
                        val = random.choice(["黑色", "白色", "红色", "蓝色"])
                    elif attr_name in ["面料", "材质", "处理器型号", "显卡型号"]:
                        val = random.choice(["优质材料", "标准款", "高性能版"])
                    cur.execute(
                        "INSERT IGNORE INTO sp_product_attributes (product_id, attribute_id, value, sort_order) "
                        "VALUES (%s, %s, %s, 0)",
                        (spu_id, attr_id, val),
                    )

        print(f"  SPU: {product_count}, SKU: {total_skus}")

        cat_brand_groups = {
            11: range(1, 7), 12: range(1, 12), 13: range(1, 8),
            14: range(1, 8), 15: range(1, 8),
            16: [12, 13, 14, 15, 16, 21, 30, 32],
            17: [14, 15, 16, 17, 30, 31, 32],
            18: [12, 13, 14, 15, 16],
            19: [12, 13, 17, 18, 19, 20],
            20: [12, 13, 14, 15, 16, 17, 18, 19, 20],
            21: [12, 13, 14, 15, 16, 30, 31, 32],
            22: range(22, 26), 23: range(22, 26), 24: range(22, 26),
            25: range(22, 26), 26: range(22, 26),
            28: range(26, 30), 29: range(26, 30),
            30: [26, 27, 28, 29], 31: [26, 27, 28, 29], 32: [26, 27, 28, 29],
            33: [12, 13, 17, 18, 19, 20],
            34: [12, 13, 17, 18, 19, 20],
            35: [12, 13, 17, 18, 19, 20],
        }
        cb_count = 0
        for i, (cat_parent_id, _, cat_level) in enumerate(CATEGORIES, 1):
            if cat_level == 1:
                continue
            key = i if cat_level == 2 else cat_parent_id
            group = cat_brand_groups.get(key, range(1, len(BRANDS) + 1))
            brand_ids = random.sample(list(group), min(len(list(group)), random.randint(3, 8)))
            for bid in brand_ids:
                cur.execute(
                    "INSERT IGNORE INTO sp_category_brands (category_id, brand_id) VALUES (%s, %s)",
                    (cat_ids[i], bid),
                )
                cb_count += 1
        print(f"  类目-品牌: {cb_count}")

    conn.commit()
    print("商品中心 ✅\n")


# ── 库存中心 ──────────────────────────────────────

def seed_inventory(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM mch_merchants WHERE deleted_at IS NULL ORDER BY id")
        merchant_ids = [row[0] for row in cur.fetchall()] or [0]

        cur.execute("SELECT id FROM sp_warehouses LIMIT 1")
        wh = cur.fetchone()
        if not wh:
            merchant_id = random.choice(merchant_ids)
            cur.execute(
                "INSERT INTO sp_warehouses (merchant_id, warehouse_name, warehouse_type, status) "
                "VALUES (%s, %s, 1, 1)", (merchant_id, "默认仓库"),
            )
            wh_id = cur.lastrowid
        else:
            wh_id = wh[0]

        cur.execute("SELECT id, merchant_id FROM sp_skus WHERE deleted_at IS NULL")
        skus = cur.fetchall()
        for sku_id, sku_merchant_id in skus:
            roll = random.random()
            if roll < 0.10:
                qty, reserved, threshold = 0, 0, random.randint(5, 30)
                status = 3
            elif roll < 0.25:
                threshold = random.randint(10, 30)
                qty = random.randint(1, threshold - 1)
                reserved = random.randint(0, min(qty, 5))
                status = 2
            else:
                qty = random.randint(50, 1000)
                reserved = random.randint(0, int(qty * 0.3))
                threshold = random.randint(5, 50)
                status = 1 if qty > threshold else 2
            cur.execute(
                "INSERT INTO sp_inventories (sku_id, merchant_id, warehouse_id, quantity, reserved, threshold, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (sku_id, sku_merchant_id, wh_id, qty, reserved, threshold, status),
            )

            if random.random() < 0.3:
                delta = random.randint(10, 50)
                cur.execute(
                    "INSERT INTO sp_inventory_logs (sku_id, merchant_id, warehouse_id, before_quantity, after_quantity, "
                    "before_reserved, after_reserved, change_amount, "
                    "change_type, reference_id, operator, note) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                    (sku_id, sku_merchant_id, wh_id, qty - delta, qty, 0, reserved, delta,
                     "purchase", f"PURCHASE_{sku_id}", "admin", "初始入库"),
                )
    conn.commit()
    print(f"  库存: {len(skus)} 条")
    print("库存中心 ✅\n")


# ── 营销中心 ──────────────────────────────────────

def seed_marketing(conn):
    now = datetime.now()
    now_str = now.strftime(FMT)

    promos = [
        ("满200减30", 4, 20000, 3000, 1, 1000),
        ("满500减100", 4, 50000, 10000, 1, 500),
        ("满1000减200", 4, 100000, 20000, 1, 300),
        ("全场8折", 5, 0, 20, 0, 0),
        ("全场85折", 5, 0, 15, 0, 0),
        ("新用户满减券", 1, 0, 5000, 1, 500),
        ("新用户专属8折", 1, 0, 20, 1, 300),
        ("会员9折", 6, 0, 10, 0, 0),
        ("会员85折", 6, 0, 15, 0, 0),
        ("限时秒杀-手机", 3, 0, 50, 1, 50),
        ("限时秒杀-耳机", 3, 0, 30, 2, 100),
        ("限时秒杀-运动鞋", 3, 0, 40, 1, 80),
        ("限时秒杀-化妆品", 3, 0, 25, 2, 120),
        ("双11预售", 2, 0, 0, 1, 1000),
        ("618大促", 2, 0, 0, 1, 1000),
        ("品牌日特惠", 2, 0, 0, 1, 500),
        ("圣诞限定折扣", 2, 0, 0, 1, 300),
    ]

    with conn.cursor() as cur:
        cur.execute("SELECT id FROM mch_merchants WHERE deleted_at IS NULL ORDER BY id")
        merchant_ids = [row[0] for row in cur.fetchall()] or [0]

        for i, (name, ptype, condition, benefit, per_limit, total_qty) in enumerate(promos, 1):
            start = (now - timedelta(days=random.randint(0, 5))).strftime(FMT)
            end = (now + timedelta(days=random.randint(3, 30))).strftime(FMT)
            status = random.choices([1, 2, 3], weights=[1, 8, 1])[0]
            merchant_id = random.choice(merchant_ids)

            promo_no = f"PROMO{i:04d}"
            cur.execute(
                "INSERT INTO mkt_promotions (promotion_no, merchant_id, promo_name, promo_type, promo_code, start_time, end_time, "
                "total_quantity, per_user_limit, used_quantity, status, priority, created_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (promo_no, merchant_id, name, ptype, f"CODE{i:04d}", start, end,
                 total_qty, per_limit, random.randint(0, int(total_qty * 0.5)), status, 0, now_str),
            )
            promo_id = cur.lastrowid

            benefit_config = json.dumps({"type": 1 if ptype in [4, 5, 6, 7, 8] else 2, "value": benefit})
            rule_condition = 2 if condition > 0 else 1
            cur.execute(
                "INSERT INTO mkt_promotion_rules (promotion_id, merchant_id, rule_name, condition_type, condition_value, "
                "benefit_config, is_stackable, stack_group, created_at) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (promo_id, merchant_id, f"{name}规则", rule_condition, condition,
                 benefit_config, 1, 0, now_str),
            )
            rule_id = cur.lastrowid
            cur.execute("UPDATE mkt_promotions SET rule_id = %s WHERE id = %s", (rule_id, promo_id))

            if ptype == 3:
                cur.execute("SELECT id FROM sp_products ORDER BY RAND() LIMIT %s", (random.randint(3, 8),))
                for p in cur.fetchall():
                    cur.execute(
                        "INSERT INTO mkt_promotion_products (promotion_id, merchant_id, product_type, target_id, created_at) "
                        "VALUES (%s, %s, 3, %s, %s)", (promo_id, merchant_id, p[0], now_str),
                    )

    conn.commit()
    print("营销中心 ✅\n")


# ── 通知模板 ───────────────────────────────────

def seed_notification(conn):
    with conn.cursor() as cur:
        for code, channel, title, content, category, priority in NOTIFICATION_TEMPLATES:
            cur.execute(
                "INSERT IGNORE INTO base_notification_templates "
                "(template_code, channel, title_template, content_template, category, priority, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, 1)",
                (code, channel, title, content, category, priority),
            )
    conn.commit()
    print(f"  通知模板: {len(NOTIFICATION_TEMPLATES)} 条")
    print("通知模板 ✅\n")


# ── 商户中心 ──────────────────────────────────────

def seed_merchant(conn):
    now = datetime.now()
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM sys_staff WHERE deleted_at IS NULL")
        staff_list = [u[0] for u in cur.fetchall()]

        for mch_name, mch_type, mch_level, contact, phone in MERCHANTS:
            code = f"MCH{random.randint(10000, 99999)}"
            cur.execute(
                "INSERT INTO mch_merchants (merchant_name, merchant_code, merchant_type, merchant_level, "
                "contact_person, contact_phone, status, audit_status, commission_rate, settlement_cycle, "
                "settled_at, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, 1, 1, %s, 1, %s, %s, %s)",
                (mch_name, code, mch_type, mch_level, contact, phone,
                 random.randint(10, 80),
                 now.strftime(FMT), now.strftime(FMT), now.strftime(FMT)),
            )
            merchant_id = cur.lastrowid

            for r in range(random.randint(1, 2)):
                name = f"{random.choice(['张','李','王','赵','刘'])}{random.choice(['伟','芳','娜','强','敏'])}"
                cur.execute(
                    "INSERT INTO mch_merchant_contacts (merchant_id, contact_name, contact_phone, contact_role, is_primary) "
                    "VALUES (%s, %s, %s, %s, %s)",
                    (merchant_id, name, f"138{random.randint(10000000, 99999999)}",
                     random.choice(["finance", "operation", "legal"]),
                     1 if r == 0 else 0),
                )

            cur.execute(
                "INSERT INTO mch_merchant_bank_accounts (merchant_id, bank_name, bank_branch, account_name, account_no, "
                "account_type, is_default, status) VALUES (%s, %s, %s, %s, %s, %s, 1, 1)",
                (merchant_id,
                 random.choice(["中国工商银行", "中国建设银行", "中国银行", "招商银行"]),
                 random.choice(["上海分行", "北京分行", "深圳分行", "广州分行"]),
                 mch_name, f"{random.randint(100000000000, 999999999999)}",
                 random.choice([1, 2])),
            )

            for qual in ["business_license", "brand_authorization"]:
                cur.execute(
                    "INSERT INTO mch_merchant_qualifications (merchant_id, qualification_type, qualification_name, "
                    "file_url, expire_at, status) VALUES (%s, %s, %s, %s, %s, 1)",
                    (merchant_id, qual, f"{mch_name}_{qual}",
                     f"https://cdn.eshop.dev/qual/{merchant_id}/{qual}.pdf",
                     (now + timedelta(days=random.randint(180, 730))).strftime(FMT)),
                )

            cur.execute(
                "INSERT INTO mch_merchant_balances (merchant_id, available_balance, freeze_balance, version) "
                "VALUES (%s, %s, %s, 0)",
                (merchant_id, random.randint(1000000, 50000000), random.randint(0, 500000)),
            )

            # 创建商家角色
            MCH_ROLES = [
                ('manager',          '店长',   '商家管理员，拥有商家所有权限',                       1),
                ('editor',           '编辑',   '商品/分类/品牌/属性内容维护',                       2),
                ('customer_service', '客服',   '订单处理和售后服务',                               3),
                ('finance',          '财务',   '资金结算和提现管理',                               4),
                ('warehouse',        '仓库',   '库存管理和订单发货',                               5),
            ]

            # 角色→权限映射
            MCH_ROLE_PERMS = {
                'manager':          ['*'],
                'editor':           ['product:read', 'product:create', 'product:update',
                                     'category:read', 'brand:read',
                                     'sku:read', 'sku:create', 'sku:update',
                                     'attribute:read', 'attribute_val:read',
                                     'inventory:read',
                                     'promotion:read', 'review:read',
                                     'merchant:read',
                                     'notification:read', 'notification:create'],
                'customer_service': ['product:read', 'category:read', 'sku:read',
                                     'order:read', 'order:update', 'order:cancel',
                                     'payment:read', 'refund:read', 'refund:update',
                                     'delivery:read',
                                     'review:read', 'review:reply',
                                     'merchant:read',
                                     'notification:read', 'notification:create', 'notification:update',
                                     'user:read', 'points:read', 'level:read'],
                'finance':          ['order:read', 'payment:read', 'refund:read', 'refund:update',
                                     'merchant_balance:read', 'merchant_withdraw:read',
                                     'merchant:read', 'merchant_bank:read',
                                     'product:read', 'sku:read',
                                     'notification:read'],
                'warehouse':        ['product:read', 'sku:read',
                                     'inventory:read', 'inventory:create', 'inventory:update', 'inventory:reserve',
                                     'order:read', 'order:update',
                                     'delivery:read', 'delivery:create', 'delivery:update',
                                     'notification:read'],
            }

            created_roles = {}
            for rname, rdisplay, rdesc, rsort in MCH_ROLES:
                cur.execute(
                    "INSERT INTO mch_merchant_roles (merchant_id, name, display_name, description, role_type, sort_order, status) "
                    "VALUES (%s, %s, %s, %s, 'builtin', %s, 1)",
                    (merchant_id, rname, rdisplay, rdesc, rsort),
                )
                role_id = cur.lastrowid
                created_roles[rname] = role_id

                # 分配权限
                perms = MCH_ROLE_PERMS.get(rname, [])
                if perms == ['*']:
                    cur.execute(
                        "INSERT INTO mch_merchant_role_permissions (merchant_id, role_id, permission_name) "
                        "SELECT %s, %s, name FROM sys_permissions",
                        (merchant_id, role_id),
                    )
                else:
                    for perm in perms:
                        cur.execute(
                            "INSERT IGNORE INTO mch_merchant_role_permissions (merchant_id, role_id, permission_name) "
                            "VALUES (%s, %s, %s)",
                            (merchant_id, role_id, perm),
                        )

            # 将员工分配到不同角色
            if staff_list:
                shuffled = staff_list[:]
                random.shuffle(shuffled)
                role_names = list(created_roles.keys())
                for idx, sid in enumerate(shuffled[:min(len(shuffled), 5)]):
                    role_name = role_names[idx % len(role_names)]
                    role_id = created_roles[role_name]
                    cur.execute(
                        "INSERT IGNORE INTO mch_merchant_users (merchant_id, staff_id, role_id, status) "
                        "VALUES (%s, %s, %s, 1)",
                        (merchant_id, sid, role_id),
                    )

        print(f"  商户: {len(MERCHANTS)}")
    conn.commit()
    print("商户中心 ✅\n")


# ── 用户中心 ──────────────────────────────────────

def seed_users(conn):
    with conn.cursor() as cur:
        # admin — B 端员工
        cur.execute("""
            INSERT IGNORE INTO sys_staff (id, username, password_hash, real_name, email, phone, status)
            VALUES (1, 'admin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC',
                    '管理员', 'admin@eshop.dev', '13800000001', 1)
        """)
        if cur.lastrowid:
            cur.execute("INSERT IGNORE INTO sys_staff_roles (staff_id, role_id) "
                        "VALUES (1, (SELECT id FROM sys_roles WHERE name = 'admin'))")

        # colin — B 端员工 + C 端消费者
        cur.execute("""
            INSERT IGNORE INTO sys_staff (username, password_hash, real_name, email, phone, status)
            VALUES ('colin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC',
                    '陈科林', 'colin@eshop.dev', '13800000002', 1)
        """)
        if cur.lastrowid:
            cur.execute("INSERT IGNORE INTO sys_staff_roles (staff_id, role_id) "
                        "VALUES (%s, (SELECT id FROM sys_roles WHERE name = 'user'))",
                        (cur.lastrowid,))

        cur.execute("""
            INSERT IGNORE INTO usr_users (id, username, password_hash, nickname, email, phone, status, register_source)
            VALUES (1, 'colin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC',
                    'Colin', 'colin@eshop.dev', '13800000002', 1, 'web')
        """)
        if cur.lastrowid:
            cur.execute("INSERT IGNORE INTO usr_infos (user_id) VALUES (1)")

        # colin 的收货地址（公司 + 家）
        cur.execute("DELETE FROM usr_addresses WHERE user_id = 1")
        cur.execute("""
            INSERT INTO usr_addresses (user_id, consignee, phone, country, province, city, district, detail, zip_code, tag, is_default)
            VALUES (1, '陈科林', '13900139001', '中国', '广东省', '深圳市', '南山区', '科技园南区高新南一道2号飞亚达科技大厦12F', '518057', 'company', 1)
        """)
        cur.execute("""
            INSERT INTO usr_addresses (user_id, consignee, phone, country, province, city, district, detail, zip_code, tag, is_default)
            VALUES (1, '陈科林', '13900139002', '中国', '广东省', '广州市', '天河区', '珠江新城华夏路16号富力盈凯广场3001', '510623', 'home', FALSE)
        """)
    conn.commit()
    print("  B端员工: admin, colin (固定)")
    print("  C端用户: colin (固定)")
    print("  地址: 公司 + 家 (2 条)")
    print("用户中心 ✅\n")


# ── 部门中心 ──────────────────────────────────────

def seed_departments(conn):
    with conn.cursor() as cur:
        DEPARTMENTS = [
            (1,  "研发中心",  0, 1),
            (2,  "运营部",    0, 2),
            (3,  "财务部",    0, 3),
            (4,  "客服部",    0, 4),
            (5,  "仓储物流部", 0, 5),
            (6,  "人事行政部", 0, 6),
            (7,  "市场部",    0, 7),
            (8,  "前端组",    1, 1),
            (9,  "后端组",    1, 2),
            (10, "测试组",    1, 3),
            (11, "内容运营组", 2, 1),
            (12, "商家运营组", 2, 2),
            (13, "数据分析组", 2, 3),
        ]

        for dept_id, name, parent_id, sort_order in DEPARTMENTS:
            cur.execute(
                "INSERT IGNORE INTO sys_departments (id, name, parent_id, sort_order, status) "
                "VALUES (%s, %s, %s, %s, 1)",
                (dept_id, name, parent_id, sort_order),
            )

        # 员工 → 部门映射（username → department_id）
        STAFF_DEPT = {
            'admin':     [(1, 1), (2, 1)],   # 管理员同时管研发中心和运营部
            'colin':     [(2, 1)],            # 陈科林 → 运营部
            'op_user':   [(11, 1)],           # 运营小张 → 内容运营组
            'editor':    [(11, 1)],           # 编辑小李 → 内容运营组
            'wh_user':   [(5, 1)],            # 仓库小王 → 仓储物流部
            'fin_user':  [(3, 1)],            # 财务小赵 → 财务部
            'mch_user':  [(12, 1)],           # 商户小刘 → 商家运营组
            'spt_user':  [(4, 1)],            # 客服小陈 → 客服部
            'aly_user':  [(13, 1)],           # 分析师小周 → 数据分析组
        }

        assigned = 0
        for username, depts in STAFF_DEPT.items():
            cur.execute("SELECT id FROM sys_staff WHERE username = %s AND deleted_at IS NULL", (username,))
            staff_row = cur.fetchone()
            if not staff_row:
                continue
            staff_id = staff_row[0]
            for dept_id, is_primary in depts:
                cur.execute(
                    "INSERT IGNORE INTO sys_staff_departments (staff_id, department_id, is_primary) "
                    "VALUES (%s, %s, %s)",
                    (staff_id, dept_id, is_primary),
                )
                assigned += 1

    conn.commit()
    print(f"  部门: {len(DEPARTMENTS)}, 员工-部门: {assigned} 条")
    print("部门中心 ✅\n")


# ── 用户中心 等级──────────────────────────────────

def seed_level(conn):
    now = datetime.now()
    now_str = now.strftime(FMT)

    with conn.cursor() as cur:
        for level_data in USER_LEVEL:
            cur.execute(
                "INSERT INTO usr_levels (name, level, min_points, discount_rate, "
                "free_shipping, points_multiplier, benefits, status, sort_order, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (
                    level_data['name'],
                    level_data['level'],
                    level_data['min_points'],
                    level_data['discount_rate'],
                    level_data['free_shipping'],
                    level_data['points_multiplier'],
                    json.dumps(level_data['benefits'], ensure_ascii=False),
                    level_data['status'],
                    level_data['sort_order'],
                    now_str,
                    now_str,
                )
            )
    conn.commit()
    print(f"  用户等级: {len(USER_LEVEL)} 条")
    print("用户等级 ✅\n")

# ── 订单中心 ──────────────────────────────────────

def seed_order(conn):
    now = datetime.now()

    with conn.cursor() as cur:
        cur.execute("SELECT id FROM mch_merchants WHERE deleted_at IS NULL ORDER BY id")
        merchant_ids = [row[0] for row in cur.fetchall()] or [0]

        cur.execute("""
            SELECT s.id, s.product_id, s.sku_code, s.price, s.spec_summary, p.name, p.main_image, p.merchant_id
            FROM sp_skus s JOIN sp_products p ON p.id = s.product_id
            WHERE s.deleted_at IS NULL AND p.deleted_at IS NULL
        """)
        skus = cur.fetchall()
        if not skus:
            print("  ⚠ 无 SKU 数据，跳过订单生成")
            return
        sku_weights = [max(1, 100 - i * 0.4) for i in range(len(skus))]

        cur.execute("SELECT id FROM usr_users WHERE deleted_at IS NULL")
        users = cur.fetchall()
        if len(users) < 20:
            existing_ids = {u[0] for u in users}
            for i in range(1, 51):
                if i in existing_ids:
                    continue
                username = f"test_user_{i}"
                nickname = f"{random.choice(['小明','小红','张三','李四','王五','赵六','测试','游客'])}{i}"
                cur.execute(
                    "INSERT IGNORE INTO usr_users (username, password_hash, nickname, phone, email, status, register_source) "
                    "VALUES (%s, %s, %s, %s, %s, 1, 'pc')",
                    (username, f"hash_{i}", nickname, f"1{i:09d}", f"user{i}@test.com"),
                )
                if cur.lastrowid:
                    cur.execute("INSERT IGNORE INTO usr_infos (user_id) VALUES (%s)", (cur.lastrowid,))
                    existing_ids.add(cur.lastrowid)
            conn.commit()
            cur.execute("SELECT id FROM usr_users WHERE deleted_at IS NULL")
            users = cur.fetchall()

        cur.execute("SELECT id, promo_type FROM mkt_promotions")
        for promo_id, promo_type in cur.fetchall():
            if promo_type == 3:
                continue
            recipients = random.sample(users, min(len(users), max(1, int(len(users) * random.uniform(0.3, 0.8)))))
            for u in recipients:
                expire = now + timedelta(days=random.randint(7, 60))
                cur.execute(
                    "INSERT IGNORE INTO mkt_user_promotions (user_promotion_no, user_id, promotion_id, expire_time, status) "
                    "VALUES (%s, %s, %s, %s, 1)",
                    (f"UPROMO{u[0]}-{promo_id}", u[0], promo_id, expire.strftime(FMT)),
                )

        total_orders = 0
        total_items = 0
        total_payments = 0

        for _ in range(2000):
            order_date = now - timedelta(
                days=random.randint(0, 30), hours=random.randint(0, 23), minutes=random.randint(0, 59),
            )
            order_no = f"ORD{order_date.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
            user_id = random.choice(users)[0]
            parent_status = random.choices(PARENT_ORDER_STATUSES, weights=PARENT_ORDER_STATUS_WEIGHTS)[0]
            sub_status = SUB_ORDER_STATUS_MAP[parent_status]

            item_count = random.randint(1, 4)
            order_skus = random.choices(skus, weights=sku_weights, k=item_count)
            total_amount = 0
            order_items = []

            for sku in order_skus:
                sku_id, prod_id, sku_code, price, spec, prod_name, image, sku_merchant_id = sku
                qty = random.randint(1, 3)
                subtotal = price * qty
                total_amount += subtotal
                order_items.append((sku_id, prod_id, sku_code, price, qty, subtotal, prod_name, image, spec, sku_merchant_id))

            shipping_fee = random.choice([0, 0, 0, 800, 1200])
            discount = random.randint(0, int(total_amount * 0.1))
            pay_amount = total_amount + shipping_fee - discount
            if pay_amount <= 0:
                pay_amount = total_amount

            payment_status = "paid" if parent_status in ("paid", "completed") \
                else "unpaid" if parent_status == "pending" \
                else "refunded"

            consignee = f"用户{user_id}"
            phone = f"138{random.randint(10000000, 99999999)}"

            # 取第一个订单项的商品所属商家作为整个订单的商家
            order_merchant_id = order_items[0][9] if order_items else random.choice(merchant_ids)

            cur.execute(
                """INSERT INTO tx_orders (order_no, user_id, total_amount, discount_amount, shipping_fee,
                   pay_amount, status, payment_status, consignee, phone,
                   province, city, district, detail_addr, source, created_at, updated_at)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (order_no, user_id, total_amount, discount, shipping_fee,
                 pay_amount, parent_status, payment_status,
                 consignee, phone,
                 random.choice(["广东省", "浙江省", "北京市", "上海市", "四川省"]),
                 random.choice(["广州市", "杭州市", "海淀区", "浦东新区", "成都市"]),
                 random.choice(["天河区", "西湖区", "中关村", "陆家嘴", "高新区"]),
                 f"{random.randint(100,999)}号{random.choice(['小区','大厦','路'])}{random.randint(1,99)}栋",
                 random.choice(["pc", "mobile", "pc", "pc"]),
                 order_date.strftime(FMT), order_date.strftime(FMT)),
            )
            order_id = cur.lastrowid

            sub_order_no = f"SO{order_date.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
            sub_total = total_amount
            sub_shipping = shipping_fee
            sub_discount = discount
            sub_pay = pay_amount

            time_fields = {}
            if parent_status in ("paid", "completed"):
                time_fields["paid_at"] = (order_date + timedelta(minutes=random.randint(1, 60))).strftime(FMT)
            if sub_status in ("shipped", "delivered"):
                time_fields["shipped_at"] = (order_date + timedelta(hours=random.randint(2, 48))).strftime(FMT)
            if sub_status == "delivered":
                time_fields["delivered_at"] = (order_date + timedelta(hours=random.randint(48, 120))).strftime(FMT)
            if parent_status == "completed":
                time_fields["completed_at"] = (order_date + timedelta(days=random.randint(3, 7))).strftime(FMT)
            if parent_status == "cancelled":
                time_fields["closed_at"] = (order_date + timedelta(hours=random.randint(1, 24))).strftime(FMT)

            cur.execute(
                """INSERT INTO tx_sub_orders (sub_order_no, parent_order_id, parent_order_no, user_id, merchant_id,
                   total_amount, discount_amount, shipping_fee, pay_amount, status,
                   paid_at, shipped_at, delivered_at, completed_at, closed_at,
                   created_at, updated_at)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                   %s, %s, %s, %s, %s, %s, %s)""",
                (sub_order_no, order_id, order_no, user_id, order_merchant_id,
                 sub_total, sub_discount, sub_shipping, sub_pay, sub_status,
                 time_fields.get("paid_at"), time_fields.get("shipped_at"),
                 time_fields.get("delivered_at"), time_fields.get("completed_at"),
                 time_fields.get("closed_at"),
                 order_date.strftime(FMT), order_date.strftime(FMT)),
            )
            sub_order_id = cur.lastrowid

            for item in order_items:
                sku_id, prod_id, sku_code, price, qty, subtotal, prod_name, image, spec, sku_merchant_id = item
                cur.execute(
                    """INSERT INTO tx_order_items (order_id, sub_order_id, merchant_id, order_no, sub_order_no,
                       sku_id, product_id, sku_code, product_name, sku_spec_summary, image,
                       price, quantity, subtotal, created_at, updated_at)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                    (order_id, sub_order_id, sku_merchant_id, order_no, sub_order_no,
                     sku_id, prod_id, sku_code, prod_name,
                     spec if spec and spec != "{}" else None, image,
                     price, qty, subtotal,
                     order_date.strftime(FMT), order_date.strftime(FMT)),
                )
                total_items += 1

                if parent_status not in ("cancelled", "pending"):
                    cur.execute(
                        "SELECT quantity, reserved FROM sp_inventories WHERE sku_id = %s FOR UPDATE",
                        (sku_id,),
                    )
                    inv = cur.fetchone()
                    if inv:
                        before_qty, before_reserved = int(inv[0]), int(inv[1])
                        after_qty = max(0, before_qty - qty)
                        after_reserved = max(0, before_reserved - qty)
                        cur.execute(
                            "UPDATE sp_inventories SET quantity = %s, reserved = %s, status = %s WHERE sku_id = %s",
                            (after_qty, after_reserved,
                             3 if after_qty <= 0 else 2 if after_qty < 10 else 1, sku_id),
                        )
                        cur.execute(
                            """INSERT INTO sp_inventory_logs (sku_id, merchant_id, change_type, before_quantity, after_quantity,
                               before_reserved, after_reserved, change_amount, reference_id, operator, note)
                               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                             (sku_id, sku_merchant_id, "order", before_qty, after_qty,
                              before_reserved, after_reserved, -qty, f"{order_no}_{sku_id}_{random.randint(100,999)}", "system", "订单扣减"),
                        )

            if parent_status in ("paid", "completed", "refunded"):
                paid_at = order_date + timedelta(minutes=random.randint(1, 60))
                payment_no = f"PAY{paid_at.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
                payment_method = random.choice(["alipay", "wechat", "alipay", "wechat", "wallet"])
                idempotency_key = f"PAY_{order_no}_{order_id}"
                cur.execute(
                    """INSERT INTO tx_payments (payment_no, order_no, order_id, merchant_id, amount, payment_method,
                       channel, trade_type, idempotency_key, status, paid_at, created_at, updated_at)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                    (payment_no, order_no, order_id, order_merchant_id, pay_amount, payment_method,
                     payment_method, "native", idempotency_key,
                     "success" if parent_status != "refunded" else "refunded",
                     paid_at.strftime(FMT), order_date.strftime(FMT), paid_at.strftime(FMT)),
                )
                payment_id = cur.lastrowid
                total_payments += 1

                if parent_status == "refunded":
                    refund_no = f"RFD{paid_at.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
                    refund_idempotency_key = f"RFD_{refund_no}_{order_id}"
                    cur.execute(
                        """INSERT INTO tx_refunds (refund_no, payment_id, payment_no, order_no, order_id, merchant_id,
                           amount, reason, status, idempotency_key, applied_at, success_at, created_at, updated_at)
                           VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                        (refund_no, payment_id, payment_no, order_no, order_id, order_merchant_id,
                         pay_amount, "测试退款", "success", refund_idempotency_key,
                         (order_date + timedelta(days=1)).strftime(FMT),
                         paid_at.strftime(FMT), order_date.strftime(FMT), paid_at.strftime(FMT)),
                    )

            total_orders += 1

    conn.commit()
    print(f"  订单: {total_orders}, 订单项: {total_items}, 支付: {total_payments}")
    print("订单中心 ✅\n")


# ── 积分中心 ──────────────────────────────────────

def seed_points(conn):
    now = datetime.now()

    with conn.cursor() as cur:
        cur.execute("SELECT id FROM usr_users WHERE deleted_at IS NULL")
        users = [u[0] for u in cur.fetchall()]
        if not users:
            print("  ⚠ 无用户数据，跳过积分生成")
            return

        # 获取已支付的订单（用于 order/review 来源关联）
        cur.execute(
            "SELECT id, user_id, pay_amount, created_at FROM tx_orders "
            "WHERE status IN ('paid','completed') AND deleted_at IS NULL"
        )
        orders = cur.fetchall()
        # 按 user_id 分组
        user_orders = {u: [] for u in users}
        for oid, ouid, amount, otime in orders:
            if ouid in user_orders:
                user_orders[ouid].append((oid, amount, otime))

        total_records = 0

        for user_id in users:
            balance = 0
            records = []

            # 1. 签到积分 — 过去 30 天随机签到（~40% 签到率）
            for day_offset in range(30):
                if random.random() < 0.4:
                    day = (now - timedelta(days=day_offset)).strftime(FMT)
                    points = 5
                    balance += points
                    records.append({
                        "user_id": user_id, "points": points,
                        "balance_after": balance,
                        "source": "signin", "source_id": "",
                        "status": 1, "remark": "每日签到奖励",
                        "created_at": day,
                    })

            # 2. 订单消费积分（1元 = 1 积分）
            for oid, amount, otime in user_orders.get(user_id, []):
                points = int(amount)
                if points <= 0:
                    continue
                balance += points
                records.append({
                    "user_id": user_id, "points": points,
                    "balance_after": balance,
                    "source": "order", "source_id": str(oid),
                    "status": 1, "remark": f"订单消费{amount}积分奖励",
                    "created_at": otime.strftime(FMT) if hasattr(otime, "strftime") else str(otime),
                })

            # 3. 评价奖励（约 30% 的订单有评价）
            for oid, amount, otime in user_orders.get(user_id, []):
                if random.random() < 0.3:
                    points = 20
                    balance += points
                    review_time = otime + timedelta(days=1)
                    records.append({
                        "user_id": user_id, "points": points,
                        "balance_after": balance,
                        "source": "review", "source_id": str(oid),
                        "status": 1, "remark": "评价奖励积分",
                        "created_at": review_time.strftime(FMT) if hasattr(review_time, "strftime") else str(review_time),
                    })

            # 4. 管理员调整（仅固定用户 colin）
            if user_id == 1 and random.random() < 0.5:
                adj_points = random.choice([100, 200, 300, 500])
                balance += adj_points
                records.append({
                    "user_id": user_id, "points": adj_points,
                    "balance_after": balance,
                    "source": "admin", "source_id": "",
                    "status": 1, "remark": "管理员手动调整积分",
                    "created_at": (now - timedelta(days=random.randint(1, 10))).strftime(FMT),
                })

            # 5. 部分过期积分（选择较早的记录标记过期）
            active_records = [r for r in records if r["source"] != "expire"]
            if active_records and len(active_records) > 5 and random.random() < 0.3:
                expire_amount = random.randint(50, 200)
                last_balance = records[-1]["balance_after"]
                records.append({
                    "user_id": user_id, "points": -expire_amount,
                    "balance_after": last_balance - expire_amount,
                    "source": "expire", "source_id": "",
                    "status": 2, "remark": "积分过期清零",
                    "created_at": (now - timedelta(days=random.randint(0, 3))).strftime(FMT),
                })

            if not records:
                continue

            # 按时间排序后入库
            records.sort(key=lambda r: r["created_at"])
            for r in records:
                cur.execute(
                    "INSERT INTO usr_points "
                    "(user_id, points, balance_after, source, source_id, status, remark, created_at) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                    (r["user_id"], r["points"], r["balance_after"],
                     r["source"], r["source_id"], r["status"], r["remark"], r["created_at"]),
                )
                total_records += 1

    conn.commit()
    print(f"  积分流水: {total_records} 条")
    print("积分中心 ✅\n")


# ── 积分规则 ──────────────────────────────────────

def seed_points_rules(conn):
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE usr_points_rules")
        for rule in POINTS_RULES:
            cur.execute(
                "INSERT INTO usr_points_rules (name, rule_key, value_int, value_decimal, value_string, description, sort_order, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                (rule["name"], rule["rule_key"],
                 rule.get("value_int"), rule.get("value_decimal"), rule.get("value_string", ""),
                 rule["description"], rule["sort_order"], rule["status"]),
            )
    conn.commit()
    print(f"  积分规则: {len(POINTS_RULES)} 条")
    print("积分规则 ✅\n")


# ── 等级升降级规则 ──────────────────────────────

def seed_level_rules(conn):
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE usr_level_rules")
        for rule in LEVEL_RULES:
            cur.execute(
                "INSERT INTO usr_level_rules (name, rule_type, from_level_id, to_level_id, "
                "condition_type, condition_value, description, sort_order, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (rule["name"], rule["rule_type"], rule["from_level_id"], rule["to_level_id"],
                 rule["condition_type"], rule["condition_value"], rule["description"],
                 rule["sort_order"], rule["status"]),
            )
    conn.commit()
    print(f"  等级升降级规则: {len(LEVEL_RULES)} 条")
    print("等级升降级规则 ✅\n")


# ── 评价中心 ──────────────────────────────────────

def seed_review(conn):
    now = datetime.now()

    with conn.cursor() as cur:
        cur.execute("""
            SELECT oi.id, oi.order_id, oi.product_id, oi.sku_id,
                   o.user_id, o.created_at, oi.merchant_id
            FROM tx_order_items oi
            JOIN tx_orders o ON o.id = oi.order_id
            WHERE o.status IN ('paid','completed') AND o.deleted_at IS NULL
              AND oi.id NOT IN (SELECT order_item_id FROM rev_reviews WHERE status != 3)
            ORDER BY o.created_at DESC
        """)
        items = cur.fetchall()
        if not items:
            print("  ⚠ 无已支付订单项，跳过评价生成")
            return

        items = list(items)
        random.shuffle(items)
        review_items = [it for it in items if random.random() < 0.5][:500]
        if not review_items:
            print("  ⚠ 无评价生成")
            return

        review_contents = {
            (5, 4): [
                "商品质量很好，做工精致，值得购买！",
                "物流很快，包装完好，好评！",
                "颜色和图片一致，非常满意。",
                "非常满意的一次购物体验！",
                "性价比很高，下次还会回购。",
                "发货速度快，客服态度也很好。",
                "用了几天才来评价，效果超出预期。",
                "质量不错，价格合理，推荐购买。",
            ],
            (3, 3): [
                "整体还不错，但细节有待改进。",
                "一般般吧，没有想象中好。",
                "中规中矩，没有惊喜。",
                "还行吧，但性价比一般。",
            ],
            (1, 2): [
                "质量太差了，完全不值这个价。",
                "很失望，和描述不符。",
                "收到就有瑕疵，体验很差。",
                "不会再买了，质量堪忧。",
            ],
        }

        total_reviews = 0
        total_media = 0
        total_replies = 0
        total_audit_logs = 0

        for item in review_items:
            item_id, order_id, spu_id, sku_id, user_id, order_time, item_merchant_id = item

            rating_weights = [1, 2, 10, 30, 57]
            overall = random.choices([1, 2, 3, 4, 5], weights=rating_weights)[0]
            quality = max(1, min(5, overall + random.randint(-1, 1)))
            logistics = max(1, min(5, overall + random.randint(-1, 1)))
            service = max(1, min(5, overall + random.randint(-1, 1)))

            if overall <= 2:
                bucket = (1, 2)
            elif overall == 3:
                bucket = (3, 3)
            else:
                bucket = (5, 4)
            content = random.choice(review_contents[bucket])
            is_anonymous = random.choice([0, 0, 0, 1])

            status = random.choices([0, 1, 2], weights=[1, 8, 1])[0]
            reject_reason = None
            if status == 2:
                reject_reason = random.choice([
                    "含不当言论", "图片与商品无关", "恶意评价",
                ])

            review_time = order_time + timedelta(days=random.randint(1, 10))

            review_no = f"RV{review_time.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
            content_length = len(content) if content else 0
            has_media = 1 if (status == 1 and random.random() < 0.3) else 0
            risk_level = 0
            cur.execute(
                """INSERT INTO rev_reviews
                   (review_no, user_id, order_id, order_item_id, spu_id, sku_id, merchant_id,
                    overall_rating, quality_rating, logistics_rating, service_rating,
                    content, content_length, is_anonymous, has_media,
                    status, risk_level, reject_reason,
                    reply_count, like_count, helpful_count,
                    created_at, updated_at)
                   VALUES (%s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (review_no, user_id, order_id, item_id, spu_id, sku_id, item_merchant_id,
                 overall, quality, logistics, service,
                 content, content_length, is_anonymous, has_media,
                 status, risk_level, reject_reason,
                 0, random.randint(0, 20), random.randint(0, 10),
                 review_time.strftime(FMT), review_time.strftime(FMT)),
            )
            review_id = cur.lastrowid
            total_reviews += 1

            cur.execute(
                "INSERT INTO rev_review_audit_logs (review_id, action, operator_id, operator_name, before_status, after_status, remark, created_at) "
                "VALUES (%s, 'submit', %s, 'user', NULL, %s, '用户提交评价', %s)",
                (review_id, user_id, status, review_time.strftime(FMT)),
            )
            total_audit_logs += 1

            if status == 1:
                cur.execute(
                    "INSERT INTO rev_review_audit_logs (review_id, action, operator_id, operator_name, before_status, after_status, remark, created_at) "
                    "VALUES (%s, 'approve', 1, 'admin', 0, 1, '审核通过', %s)",
                    (review_id, review_time.strftime(FMT)),
                )
                total_audit_logs += 1
            elif status == 2:
                cur.execute(
                    "INSERT INTO rev_review_audit_logs (review_id, action, operator_id, operator_name, before_status, after_status, remark, created_at) "
                    "VALUES (%s, 'reject', 1, 'admin', 0, 2, %s, %s)",
                    (review_id, reject_reason, review_time.strftime(FMT)),
                )
                total_audit_logs += 1

            if status == 1 and random.random() < 0.3:
                for m in range(random.randint(1, 3)):
                    cur.execute(
                        "INSERT INTO rev_review_media (review_id, media_type, media_url, file_size, width, height, sort_order, created_at) "
                        "VALUES (%s, 1, %s, %s, %s, %s, %s, %s)",
                        (review_id, f"https://cdn.eshop.dev/reviews/{review_id}/{m+1}.jpg",
                         random.randint(50000, 500000), random.randint(800, 1920), random.randint(800, 1920),
                         m, review_time.strftime(FMT)),
                    )
                    total_media += 1

            if status == 1 and random.random() < 0.2:
                reply_content = random.choice([
                    "感谢您的评价，我们会继续努力！",
                    "谢谢您的支持，欢迎再次光临！",
                    "感谢您的反馈，我们会不断改进。",
                ])
                cur.execute(
                    "INSERT INTO rev_review_replies (review_id, parent_id, root_reply_id, reply_type, content, operator_id, operator_name, status, created_at, updated_at) "
                    "VALUES (%s, NULL, NULL, 1, %s, 1, 'admin', 1, %s, %s)",
                    (review_id, reply_content, review_time.strftime(FMT), review_time.strftime(FMT)),
                )
                reply_id = cur.lastrowid
                total_replies += 1

                cur.execute(
                    "UPDATE rev_reviews SET reply_count = reply_count + 1 WHERE id = %s",
                    (review_id,),
                )

                if random.random() < 0.3:
                    cur.execute(
                        "INSERT INTO rev_review_replies (review_id, parent_id, root_reply_id, reply_type, content, operator_id, operator_name, status, created_at, updated_at) "
                        "VALUES (%s, %s, %s, 2, %s, %s, 'user', 1, %s, %s)",
                        (review_id, reply_id, reply_id,
                         random.choice(["不客气，还会再来的！", "希望你们越做越好！"]),
                         user_id,
                         (review_time + timedelta(hours=random.randint(1, 24))).strftime(FMT),
                         (review_time + timedelta(hours=random.randint(1, 24))).strftime(FMT)),
                    )
                    total_replies += 1

        cur.execute("""
            UPDATE sp_products p
            SET p.rating_average = (
                SELECT ROUND(COALESCE(AVG(r.overall_rating), 0), 2)
                FROM rev_reviews r
                WHERE r.spu_id = p.id AND r.status = 1
            ),
            p.rating_count = (
                SELECT COUNT(*)
                FROM rev_reviews r
                WHERE r.spu_id = p.id AND r.status = 1
            )
            WHERE p.deleted_at IS NULL
        """)

    conn.commit()
    print(f"  评价: {total_reviews}, 媒体: {total_media}, 回复: {total_replies}, 审核日志: {total_audit_logs}")
    print("评价中心 ✅\n")


# ── 主入口 ──────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="为新表生成测试数据")
    parser.add_argument("--clean", action="store_true", help="先清空再生成")
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
        "users": seed_users,
        "departments": seed_departments,
        "level": seed_level,
        "merchant": seed_merchant,
        "order": seed_order,
        "notification": seed_notification,
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
                      "sp_inventories", "mkt_promotions", "mkt_promotion_stocks", "mkt_user_promotions",
                      "tx_orders", "tx_sub_orders", "tx_order_items", "tx_payments", "tx_refunds",
                      "tx_deliveries", "usr_addresses", "usr_levels", "usr_points", "usr_points_rules", "usr_level_rules",
                      "mch_merchants", "mch_merchant_balances",
                      "base_notification_templates",
                      "rev_reviews", "rev_review_media", "rev_review_replies", "rev_review_audit_logs",
                      "rev_review_statistics", "rev_review_usefulness"]:
            cur.execute(f"SELECT COUNT(*) AS cnt FROM {table}")
            row = cur.fetchone()
            print(f"  {table}: {row[0]}")

    conn.close()
    print("\n完成!")


if __name__ == "__main__":
    main()
