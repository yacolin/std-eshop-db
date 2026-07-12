-- ============================================================
-- 00_init.sql — PostgreSQL shared utilities
-- Must be sourced before any table creation.
-- ============================================================

-- 扩展加载（需 superuser 权限）
CREATE EXTENSION IF NOT EXISTS pg_trgm;       -- trigram 模糊搜索
CREATE EXTENSION IF NOT EXISTS btree_gist;     -- 排他约束（GIST + btree）
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";    -- UUID 生成

-- Trigger function: simulate MySQL's ON UPDATE CURRENT_TIMESTAMP
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
