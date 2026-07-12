-- ============================================================
-- 00_drop_tables.sql — PostgreSQL
-- Drops all tables in reverse dependency order (P5 -> P0)
-- ============================================================

-- P5: 版本/审计表
DROP TABLE IF EXISTS sp_product_versions;

-- P4: 仓配/售后/结算（依赖 P2/P3）
DROP TABLE IF EXISTS tx_delivery_traces;
DROP TABLE IF EXISTS tx_delivery_items;
DROP TABLE IF EXISTS tx_deliveries;
DROP TABLE IF EXISTS tx_after_sale_logs;
DROP TABLE IF EXISTS tx_after_sale_evidences;
DROP TABLE IF EXISTS tx_after_sales;
DROP TABLE IF EXISTS mch_settlement_details;
DROP TABLE IF EXISTS sp_warehouse_skus;
DROP TABLE IF EXISTS sp_warehouses;

-- P3: 库存流水表（依赖 P2）
DROP TABLE IF EXISTS sp_inventory_logs;
DROP TABLE IF EXISTS sp_inventories;

-- P2: 关联业务表（依赖 P1）
DROP TABLE IF EXISTS rev_review_usefulness;
DROP TABLE IF EXISTS rev_review_statistics;
DROP TABLE IF EXISTS rev_review_audit_logs;
DROP TABLE IF EXISTS rev_review_replies;
DROP TABLE IF EXISTS rev_review_media;
DROP TABLE IF EXISTS mkt_promotion_usage_logs;
DROP TABLE IF EXISTS mkt_promotion_stocks;
DROP TABLE IF EXISTS mkt_user_promotions;
DROP TABLE IF EXISTS mkt_promotion_products;
DROP TABLE IF EXISTS mkt_promotion_rules;
DROP TABLE IF EXISTS tx_refunds;
DROP TABLE IF EXISTS tx_payment_logs;
DROP TABLE IF EXISTS tx_payments;
DROP TABLE IF EXISTS tx_order_logs;
DROP TABLE IF EXISTS tx_order_items;
DROP TABLE IF EXISTS tx_cart_items;
DROP TABLE IF EXISTS sp_product_descriptions;
DROP TABLE IF EXISTS sp_sku_specs;
DROP TABLE IF EXISTS sp_attribute_values;
DROP TABLE IF EXISTS sp_product_attributes;
DROP TABLE IF EXISTS sp_skus;
DROP TABLE IF EXISTS sp_category_attributes;
DROP TABLE IF EXISTS sp_category_brands;

-- P1: 核心业务表（依赖 P0）
DROP TABLE IF EXISTS rev_reviews;
DROP TABLE IF EXISTS mkt_promotions;
DROP TABLE IF EXISTS tx_sub_orders;
DROP TABLE IF EXISTS tx_orders;
DROP TABLE IF EXISTS tx_carts;
DROP TABLE IF EXISTS sp_products;
DROP TABLE IF EXISTS sp_attributes;
DROP TABLE IF EXISTS mch_merchant_settlement_logs;
DROP TABLE IF EXISTS mch_merchant_withdrawals;
DROP TABLE IF EXISTS mch_merchant_balances;
DROP TABLE IF EXISTS mch_merchant_users;
DROP TABLE IF EXISTS mch_merchant_role_permissions;
DROP TABLE IF EXISTS usr_points_rules;
DROP TABLE IF EXISTS usr_points;
DROP TABLE IF EXISTS usr_level_rules;
DROP TABLE IF EXISTS usr_levels;

-- P0: 独立基础表
DROP TABLE IF EXISTS sys_operation_logs;
DROP TABLE IF EXISTS sys_staff_departments;
DROP TABLE IF EXISTS sys_departments;
DROP TABLE IF EXISTS sys_login_histories;
DROP TABLE IF EXISTS sys_staff_roles;
DROP TABLE IF EXISTS sys_staff;
DROP TABLE IF EXISTS sys_role_permissions;
DROP TABLE IF EXISTS sys_permissions;
DROP TABLE IF EXISTS sys_roles;
DROP TABLE IF EXISTS mch_merchant_roles;
DROP TABLE IF EXISTS mch_merchant_qualifications;
DROP TABLE IF EXISTS mch_merchant_bank_accounts;
DROP TABLE IF EXISTS mch_merchant_contacts;
DROP TABLE IF EXISTS mch_merchants;
DROP TABLE IF EXISTS sp_brands;
DROP TABLE IF EXISTS sp_categories;
DROP TABLE IF EXISTS usr_login_histories;
DROP TABLE IF EXISTS usr_addresses;
DROP TABLE IF EXISTS usr_infos;
DROP TABLE IF EXISTS usr_users;
DROP TABLE IF EXISTS base_notification_reads;
DROP TABLE IF EXISTS base_notifications;
DROP TABLE IF EXISTS base_notification_templates;
