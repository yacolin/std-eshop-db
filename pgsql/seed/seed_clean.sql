-- ============================================================================
-- 清理所有种子数据（按依赖顺序）
-- ============================================================================

SET session_replication_role = replica;

-- 交易
TRUNCATE TABLE tx_delivery_traces;
TRUNCATE TABLE tx_delivery_items;
TRUNCATE TABLE tx_deliveries;
TRUNCATE TABLE tx_after_sale_logs;
TRUNCATE TABLE tx_after_sales;
TRUNCATE TABLE tx_refunds;
TRUNCATE TABLE tx_payment_logs;
TRUNCATE TABLE tx_payments;
TRUNCATE TABLE tx_order_logs;
TRUNCATE TABLE tx_order_items;
TRUNCATE TABLE tx_orders;
TRUNCATE TABLE tx_cart_items;
TRUNCATE TABLE tx_carts;

-- SPU/库存/版本
TRUNCATE TABLE sp_warehouses;
TRUNCATE TABLE sp_product_versions;
TRUNCATE TABLE sp_inventory_logs;
TRUNCATE TABLE sp_inventories;
TRUNCATE TABLE sp_product_attributes;
TRUNCATE TABLE sp_product_descriptions;
TRUNCATE TABLE sp_skus;
TRUNCATE TABLE sp_category_brands;
TRUNCATE TABLE sp_products;
TRUNCATE TABLE sp_attributes;
TRUNCATE TABLE sp_categories;
TRUNCATE TABLE sp_brands;

-- 营销
TRUNCATE TABLE mkt_promotion_usage_logs;
TRUNCATE TABLE mkt_user_promotions;
TRUNCATE TABLE mkt_promotion_products;
TRUNCATE TABLE mkt_promotion_rules;
TRUNCATE TABLE mkt_promotions;

-- 评价
TRUNCATE TABLE rev_review_audit_logs;

TRUNCATE TABLE rev_review_replies;
TRUNCATE TABLE rev_review_media;
TRUNCATE TABLE rev_reviews;

-- 系统/B端员工
TRUNCATE TABLE sys_operation_logs;
TRUNCATE TABLE sys_staff_departments;
TRUNCATE TABLE sys_departments;
TRUNCATE TABLE sys_login_histories;
TRUNCATE TABLE sys_staff_roles;
TRUNCATE TABLE sys_staff;
TRUNCATE TABLE sys_role_permissions;
TRUNCATE TABLE sys_permissions;
TRUNCATE TABLE sys_roles;

-- 用户/积分/等级
TRUNCATE TABLE usr_points;
TRUNCATE TABLE usr_levels;
TRUNCATE TABLE usr_login_histories;
TRUNCATE TABLE usr_addresses;
TRUNCATE TABLE usr_infos;
TRUNCATE TABLE usr_users;

-- 消息
TRUNCATE TABLE base_notification_reads;
TRUNCATE TABLE base_notifications;
TRUNCATE TABLE base_notification_templates;

-- 商户
TRUNCATE TABLE mch_role_permissions;
TRUNCATE TABLE mch_roles;
TRUNCATE TABLE mch_settlement_details;
TRUNCATE TABLE mch_merchant_settlement_logs;
TRUNCATE TABLE mch_merchant_withdrawals;
TRUNCATE TABLE mch_merchant_balances;
TRUNCATE TABLE mch_merchant_users;
TRUNCATE TABLE mch_merchant_qualifications;
TRUNCATE TABLE mch_merchant_bank_accounts;
TRUNCATE TABLE mch_merchant_contacts;
TRUNCATE TABLE mch_merchants;

SET session_replication_role = default;

-- 重置自增
ALTER SEQUENCE usr_users_id_seq RESTART WITH 1;
ALTER SEQUENCE usr_infos_id_seq RESTART WITH 1;
ALTER SEQUENCE mch_roles_id_seq RESTART WITH 1;
ALTER SEQUENCE mch_role_permissions_id_seq RESTART WITH 1;
ALTER SEQUENCE usr_addresses_id_seq RESTART WITH 1;
ALTER SEQUENCE sys_roles_id_seq RESTART WITH 1;
ALTER SEQUENCE sys_permissions_id_seq RESTART WITH 1;
ALTER SEQUENCE sys_role_permissions_id_seq RESTART WITH 1;
ALTER SEQUENCE sys_staff_id_seq RESTART WITH 1;
ALTER SEQUENCE sys_staff_roles_id_seq RESTART WITH 1;
ALTER SEQUENCE sys_departments_id_seq RESTART WITH 1;
ALTER SEQUENCE sys_staff_departments_id_seq RESTART WITH 1;
ALTER SEQUENCE sys_login_histories_id_seq RESTART WITH 1;
ALTER SEQUENCE sys_operation_logs_id_seq RESTART WITH 1;
ALTER SEQUENCE sp_categories_id_seq RESTART WITH 1;
ALTER SEQUENCE sp_brands_id_seq RESTART WITH 1;
ALTER SEQUENCE sp_attributes_id_seq RESTART WITH 1;
ALTER SEQUENCE sp_products_id_seq RESTART WITH 1;
ALTER SEQUENCE sp_skus_id_seq RESTART WITH 1;
