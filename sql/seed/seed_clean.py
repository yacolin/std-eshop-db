#!/usr/bin/env python3
"""
清空测试数据（TRUNCATE 业务表）。
"""
from seed_common import *


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
        "sp_category_attributes", "sp_attribute_values", "sp_skus",
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
