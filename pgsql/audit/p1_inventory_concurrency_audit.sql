-- ============================================================
-- p1_inventory_concurrency_audit.sql — PostgreSQL 库存并发模型复核
-- 依据 sql/P1_库存并发模型.md
-- 用法: psql -U postgres -d eshop_db -f pgsql/audit/p1_inventory_concurrency_audit.sql
-- 说明: 输出 0 行 = 通过；输出行 = 待整改项
-- ============================================================

-- 1) sp_inventories 必须存在 version 乐观锁列（bigint）
SELECT table_name, column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = current_schema()
  AND table_name = 'sp_inventories'
  AND column_name = 'version';

-- 2) sp_inventories 数量边界 CHECK
SELECT conrelid::regclass::text AS table_name, conname,
       pg_get_constraintdef(oid) AS check_def
FROM pg_constraint
WHERE contype = 'c'
  AND connamespace = current_schema()::regnamespace
  AND conrelid::regclass::text = 'sp_inventories'
ORDER BY conname;

-- 3) mkt_promotion_stocks 版本列
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = current_schema()
  AND table_name = 'mkt_promotion_stocks'
  AND column_name = 'version';
