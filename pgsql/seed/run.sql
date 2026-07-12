-- ============================================================================
-- PostgreSQL 种子数据执行脚本（仅 SQL 部分）
-- 注意：Python 种子脚本覆盖更多业务表，推荐直接使用：
--   python pgsql/seed/seed_test_data.py --clean
-- 该命令会自动 truncate 所有业务表并重新生成完整测试数据。
--
-- 如果只想初始化 RBAC（权限/角色/员工），再单独执行此 SQL：
--   psql -U postgres -d eshop_db -f pgsql/seed/run.sql
--   python pgsql/seed/seed_test_data.py
-- ============================================================================

-- 第 1 步：清理旧种子数据
\i pgsql/seed/seed_clean.sql

-- 第 2 步：初始化 RBAC（权限、角色、员工关联）
\i pgsql/seed/seed_rbac.sql

-- 第 3 步：业务测试数据（Python，用 seed_data.py 生成随机数据）
-- python pgsql/seed/seed_test_data.py

-- 第 4 步：行级安全策略（需在数据就位后启用）
\i pgsql/05_rls.sql
