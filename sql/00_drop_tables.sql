USE eshop_db;

SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- P5: 订单分表辅助表（tx_p5.sql 纳入基线，但此前漏在本脚本里清理）
-- ============================================================
DROP TABLE IF EXISTS `tx_order_daily_stats`;
DROP TABLE IF EXISTS `tx_order_shard_map`;

-- ------------------------------------------------------------
-- 订单域 *legacy* 归档副本：分表工具的 RENAME 产物，必须删掉。
--
-- 为什么不能用静态表名：副本名带月份后缀（tx_orders_legacy_202610），无法穷举。
-- 为什么必须删：RENAME 不重命名 CHECK 约束，副本仍占用**原始**约束名
-- （chk_pay_amount / chk_total_amount / …）。MySQL 的 CHECK 约束名在 schema 内唯一，
-- 残留副本会让下面 `CREATE TABLE tx_orders` 直接报
--   Error 3822 Duplicate check constraint name 'chk_pay_amount'
-- 副本本身也只是分表迁移期的旧自增 ID 备份，重置即失效。
--
-- 注意：**月分片 tx_orders_202607 等不在此列**——它们是应用按需创建的动态对象
-- （见 sql/tx_p5.sql 头注释），不入基线，重置基线时不销毁，应用切回 monthly 仍可用。
-- ------------------------------------------------------------
SET @legacy_tables = (
    SELECT GROUP_CONCAT(CONCAT('`', TABLE_NAME, '`') SEPARATOR ', ')
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME REGEXP '^tx_(orders|sub_orders|order_items|order_logs)_legacy_[0-9]{6}$'
);
SET @sql = IFNULL(CONCAT('DROP TABLE IF EXISTS ', @legacy_tables), 'DO 0');
PREPARE stmt_drop_legacy FROM @sql;
EXECUTE stmt_drop_legacy;
DEALLOCATE PREPARE stmt_drop_legacy;

-- ============================================================
-- P4: MCH 扩展 + 物流配送（依赖 P2/P3）
-- ============================================================
DROP TABLE IF EXISTS `tx_delivery_traces`;
DROP TABLE IF EXISTS `tx_delivery_items`;
DROP TABLE IF EXISTS `tx_deliveries`;
DROP TABLE IF EXISTS `mch_merchant_role_permissions`;
DROP TABLE IF EXISTS `mch_merchant_roles`;
DROP TABLE IF EXISTS `mch_settlement_details`;
DROP TABLE IF EXISTS `tx_after_sale_logs`;
DROP TABLE IF EXISTS `tx_after_sale_evidences`;
DROP TABLE IF EXISTS `tx_after_sales`;
DROP TABLE IF EXISTS `sp_warehouses`;

-- ============================================================
-- P3: 库存流水表（依赖 P2）
-- ============================================================
DROP TABLE IF EXISTS `sp_inventory_logs`;
DROP TABLE IF EXISTS `sp_inventories`;

-- ============================================================
-- P2: 关联业务表（依赖 P1）
-- ============================================================
DROP TABLE IF EXISTS `sp_sku_specs`;
DROP TABLE IF EXISTS `sp_attribute_values`;
DROP TABLE IF EXISTS `rev_review_usefulness`;
DROP TABLE IF EXISTS `rev_review_statistics`;
DROP TABLE IF EXISTS `mkt_promotion_stocks`;
DROP TABLE IF EXISTS `sp_product_versions`;
DROP TABLE IF EXISTS `rev_review_audit_logs`;
DROP TABLE IF EXISTS `rev_review_replies`;
DROP TABLE IF EXISTS `rev_review_media`;
DROP TABLE IF EXISTS `mkt_promotion_usage_logs`;
DROP TABLE IF EXISTS `mkt_user_promotions`;
DROP TABLE IF EXISTS `mkt_promotion_products`;
DROP TABLE IF EXISTS `mkt_promotion_rules`;
DROP TABLE IF EXISTS `tx_order_logs`;
DROP TABLE IF EXISTS `tx_order_items`;
DROP TABLE IF EXISTS `tx_sub_orders`;
DROP TABLE IF EXISTS `tx_cart_items`;
DROP TABLE IF EXISTS `tx_payment_logs`;
DROP TABLE IF EXISTS `tx_refunds`;
DROP TABLE IF EXISTS `tx_payments`;
DROP TABLE IF EXISTS `sp_product_descriptions`;
DROP TABLE IF EXISTS `sp_product_attributes`;
DROP TABLE IF EXISTS `sp_skus`;
DROP TABLE IF EXISTS `sp_category_attributes`;
DROP TABLE IF EXISTS `sp_category_brands`;

-- ============================================================
-- P1: 核心业务表（依赖 P0）
-- ============================================================
DROP TABLE IF EXISTS `usr_points_rules`;
DROP TABLE IF EXISTS `usr_level_rules`;
DROP TABLE IF EXISTS `usr_points`;
DROP TABLE IF EXISTS `usr_levels`;
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
DROP TABLE IF EXISTS `sys_role_permissions`;
DROP TABLE IF EXISTS `sys_permissions`;
DROP TABLE IF EXISTS `sys_roles`;
DROP TABLE IF EXISTS `sys_operation_logs`;
DROP TABLE IF EXISTS `sys_staff_departments`;
DROP TABLE IF EXISTS `sys_departments`;
DROP TABLE IF EXISTS `sys_login_histories`;
DROP TABLE IF EXISTS `sys_staff_roles`;
DROP TABLE IF EXISTS `sys_staff`;
DROP TABLE IF EXISTS `usr_login_histories`;
DROP TABLE IF EXISTS `usr_addresses`;
DROP TABLE IF EXISTS `usr_infos`;
DROP TABLE IF EXISTS `mch_merchants`;

-- ============================================================
-- P0: 独立基础表
-- ============================================================
DROP TABLE IF EXISTS `base_notification_reads`;
DROP TABLE IF EXISTS `base_notifications`;
DROP TABLE IF EXISTS `base_notification_templates`;
DROP TABLE IF EXISTS `sp_categories`;
DROP TABLE IF EXISTS `sp_brands`;
DROP TABLE IF EXISTS `usr_users`;

SET FOREIGN_KEY_CHECKS = 1;
