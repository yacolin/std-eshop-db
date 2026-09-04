-- ============================================================
-- schema_migrations — PostgreSQL 迁移执行记录表
-- P2 Migration 体系：记录已应用的版本化迁移，保证只前向执行一次
-- 由 pgsql/migrate.sh 自动创建并维护；也可手动执行本文件初始化
-- ============================================================

CREATE TABLE IF NOT EXISTS schema_migrations (
    version       varchar(20)  NOT NULL,
    file_name     varchar(255) NOT NULL,
    description   varchar(500) NOT NULL DEFAULT '',
    checksum      varchar(64)  NOT NULL DEFAULT '',
    applied_by    varchar(64)  NOT NULL DEFAULT 'system',
    applied_at    timestamptz  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    execution_ms  int          NOT NULL DEFAULT 0,
    PRIMARY KEY (version),
    CONSTRAINT uk_migration_file UNIQUE (file_name)
);

COMMENT ON TABLE schema_migrations IS '数据库迁移执行记录表（P2 Migration 体系）';
COMMENT ON COLUMN schema_migrations.version IS '迁移版本号（如 V001）';
COMMENT ON COLUMN schema_migrations.file_name IS '迁移文件名';
COMMENT ON COLUMN schema_migrations.checksum IS '文件内容 SHA-256（防篡改/变更检测）';
