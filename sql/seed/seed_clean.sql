-- ============================================================================
-- 清理所有种子数据（按依赖顺序）
-- ============================================================================

USE eshop_db;

SET FOREIGN_KEY_CHECKS = 0;

-- 交易
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

-- SPU/库存
TRUNCATE TABLE sp_warehouse_skus;
TRUNCATE TABLE sp_warehouses;
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
TRUNCATE TABLE rev_review_ratings;
TRUNCATE TABLE rev_review_replies;
TRUNCATE TABLE rev_review_media;
TRUNCATE TABLE rev_reviews;

-- 用户/RBAC
TRUNCATE TABLE usr_login_histories;
TRUNCATE TABLE usr_role_permissions;
TRUNCATE TABLE usr_user_roles;
TRUNCATE TABLE usr_addresses;
TRUNCATE TABLE usr_infos;
TRUNCATE TABLE usr_users;
TRUNCATE TABLE usr_permissions;
TRUNCATE TABLE usr_roles;

-- 消息
TRUNCATE TABLE base_notifications;
TRUNCATE TABLE base_notification_templates;

-- 商户
TRUNCATE TABLE mch_settlement_details;
TRUNCATE TABLE mch_merchant_settlement_logs;
TRUNCATE TABLE mch_merchant_withdrawals;
TRUNCATE TABLE mch_merchant_balances;
TRUNCATE TABLE mch_merchant_users;
TRUNCATE TABLE mch_merchant_qualifications;
TRUNCATE TABLE mch_merchant_bank_accounts;
TRUNCATE TABLE mch_merchant_contacts;
TRUNCATE TABLE mch_merchants;

SET FOREIGN_KEY_CHECKS = 1;

-- 重置自增
ALTER TABLE usr_roles AUTO_INCREMENT = 1;
ALTER TABLE usr_permissions AUTO_INCREMENT = 1;
ALTER TABLE usr_users AUTO_INCREMENT = 1;
ALTER TABLE usr_infos AUTO_INCREMENT = 1;
ALTER TABLE usr_addresses AUTO_INCREMENT = 1;
ALTER TABLE usr_user_roles AUTO_INCREMENT = 1;
ALTER TABLE usr_role_permissions AUTO_INCREMENT = 1;
ALTER TABLE sp_categories AUTO_INCREMENT = 1;
ALTER TABLE sp_brands AUTO_INCREMENT = 1;
ALTER TABLE sp_attributes AUTO_INCREMENT = 1;
ALTER TABLE sp_products AUTO_INCREMENT = 1;
ALTER TABLE sp_skus AUTO_INCREMENT = 1;
