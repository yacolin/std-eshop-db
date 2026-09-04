-- ============================================================
-- p1_inventory_concurrency_audit.sql — MySQL 库存并发模型复核
-- 依据 sql/P1_库存并发模型.md
-- 用法: mysql -u root -p eshop_db < sql/audit/p1_inventory_concurrency_audit.sql
-- 说明: 输出 0 行 = 通过；输出行 = 待整改项
-- ============================================================

-- 1) sp_inventories 必须存在 version 乐观锁列（bigint NOT NULL DEFAULT 0）
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, COLUMN_DEFAULT, IS_NULLABLE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'sp_inventories'
  AND COLUMN_NAME = 'version';

-- 2) sp_inventories 数量边界 CHECK（应均有）
SELECT tc.CONSTRAINT_NAME, cc.CHECK_CLAUSE
FROM information_schema.TABLE_CONSTRAINTS tc
JOIN information_schema.CHECK_CONSTRAINTS cc
  ON cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
 AND cc.CONSTRAINT_NAME   = tc.CONSTRAINT_NAME
WHERE tc.TABLE_SCHEMA = DATABASE()
  AND tc.TABLE_NAME = 'sp_inventories'
  AND tc.CONSTRAINT_TYPE = 'CHECK';

-- 3) 促销库存版本列（mkt_promotion_stocks.version）
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'mkt_promotion_stocks'
  AND COLUMN_NAME = 'version';

-- 4) 库存流水幂等键（reference_id_uq + uk_ref_type）
SELECT INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) cols
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'sp_inventory_logs'
  AND NON_UNIQUE = 0
  AND INDEX_NAME IN ('uk_ref_type','uk_reference_id')
GROUP BY INDEX_NAME;
