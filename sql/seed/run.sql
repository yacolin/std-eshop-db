-- ============================================================================
-- 种子数据执行脚本
-- 用法: mysql -u root -p eshop_db < sql/seed/run.sql
-- ============================================================================

USE eshop_db;

-- 第 1 步：清理旧种子数据
source sql/seed/seed_clean.sql;

-- 第 2 步：初始化 RBAC（权限、角色、关联、用户、地址）
source sql/seed/seed_rbac.sql;

-- 第 3 步：批量生成测试数据（通过 Python 脚本）
-- python sql/seed/seed_test_data.py
