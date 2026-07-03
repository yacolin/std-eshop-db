-- ============================================================
-- 00_init.sql — PostgreSQL shared utilities
-- Must be sourced before any table creation.
-- ============================================================

-- Trigger function: simulate MySQL's ON UPDATE CURRENT_TIMESTAMP
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
