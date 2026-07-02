USE eshop_db;

-- ============================================================
-- P4: MCH 扩展表（依赖 P2/P3）
-- ============================================================
DROP TABLE IF EXISTS `mch_settlement_details`;
DROP TABLE IF EXISTS `tx_after_sale_logs`;
DROP TABLE IF EXISTS `tx_after_sales`;
DROP TABLE IF EXISTS `sp_warehouse_skus`;
DROP TABLE IF EXISTS `sp_warehouses`;

-- ============================================================
-- P3: 库存流水表（依赖 P2）
-- ============================================================
DROP TABLE IF EXISTS `sp_inventory_logs`;
DROP TABLE IF EXISTS `sp_inventories`;

-- ============================================================
-- P2: 关联业务表（依赖 P1）
-- ============================================================
DROP TABLE IF EXISTS `rev_review_audit_logs`;
DROP TABLE IF EXISTS `rev_review_ratings`;
DROP TABLE IF EXISTS `rev_review_replies`;
DROP TABLE IF EXISTS `rev_review_media`;
DROP TABLE IF EXISTS `mkt_promotion_usage_logs`;
DROP TABLE IF EXISTS `mkt_user_promotions`;
DROP TABLE IF EXISTS `mkt_promotion_products`;
DROP TABLE IF EXISTS `mkt_promotion_rules`;
DROP TABLE IF EXISTS `tx_order_logs`;
DROP TABLE IF EXISTS `tx_order_items`;
DROP TABLE IF EXISTS `tx_cart_items`;
DROP TABLE IF EXISTS `tx_payment_logs`;
DROP TABLE IF EXISTS `tx_payments`;
DROP TABLE IF EXISTS `tx_refunds`;
DROP TABLE IF EXISTS `sp_product_descriptions`;
DROP TABLE IF EXISTS `sp_product_attributes`;
DROP TABLE IF EXISTS `sp_skus`;
DROP TABLE IF EXISTS `sp_category_brands`;

-- ============================================================
-- P1: 核心业务表（依赖 P0）
-- ============================================================
DROP TABLE IF EXISTS `mch_merchant_settlement_logs`;
DROP TABLE IF EXISTS `mch_merchant_withdrawals`;
DROP TABLE IF EXISTS `mch_merchant_balances`;
DROP TABLE IF EXISTS `mch_merchant_users`;
DROP TABLE IF EXISTS `mch_merchant_qualifications`;
DROP TABLE IF EXISTS `mch_merchant_bank_accounts`;
DROP TABLE IF EXISTS `mch_merchant_contacts`;
DROP TABLE IF EXISTS `rev_reviews`;
DROP TABLE IF EXISTS `mkt_promotions`;
DROP TABLE IF EXISTS `tx_orders`;
DROP TABLE IF EXISTS `tx_carts`;
DROP TABLE IF EXISTS `sp_products`;
DROP TABLE IF EXISTS `sp_attributes`;
DROP TABLE IF EXISTS `usr_login_histories`;
DROP TABLE IF EXISTS `usr_role_permissions`;
DROP TABLE IF EXISTS `usr_user_roles`;
DROP TABLE IF EXISTS `usr_permissions`;
DROP TABLE IF EXISTS `usr_roles`;
DROP TABLE IF EXISTS `usr_addresses`;
DROP TABLE IF EXISTS `usr_infos`;
DROP TABLE IF EXISTS `mch_merchants`;

-- ============================================================
-- P0: 独立基础表
-- ============================================================
DROP TABLE IF EXISTS `base_notifications`;
DROP TABLE IF EXISTS `base_notification_templates`;
DROP TABLE IF EXISTS `sp_categories`;
DROP TABLE IF EXISTS `sp_brands`;
DROP TABLE IF EXISTS `usr_users`;
