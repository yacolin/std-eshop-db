-- ============================================================
-- schema_migrations — MySQL 迁移执行记录表
-- P2 Migration 体系：记录已应用的版本化迁移，保证只前向执行一次
-- 由 sql/migrate.sh 自动创建并维护；也可手动执行本文件初始化
-- 注意：不包含 USE 语句——由运行器/migrate.sh 在目标库执行
-- ============================================================

CREATE TABLE IF NOT EXISTS `schema_migrations` (
    `version`       VARCHAR(20)  NOT NULL COMMENT '迁移版本号（如 V001）',
    `file_name`     VARCHAR(255) NOT NULL COMMENT '迁移文件名',
    `description`   VARCHAR(500) NOT NULL DEFAULT '' COMMENT '迁移说明',
    `checksum`      VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '文件内容 SHA-256（防篡改/变更检测）',
    `applied_by`    VARCHAR(64)  NOT NULL DEFAULT 'system' COMMENT '执行人',
    `applied_at`    datetime(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '执行时间',
    `execution_ms`  INT          NOT NULL DEFAULT 0 COMMENT '执行耗时（毫秒）',
    PRIMARY KEY (`version`),
    UNIQUE KEY `uk_migration_file` (`file_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='数据库迁移执行记录表（P2 Migration 体系）';
