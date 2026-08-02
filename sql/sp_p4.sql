USE eshop_db;

-- ============================================================
-- sp_p4.sql — 仓库表（基础基建表，sp_p3 库存表的前置依赖；无外部外键依赖）
-- ============================================================

CREATE TABLE `sp_warehouses` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '仓库ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID（0表示平台仓）',
    `warehouse_name` VARCHAR(100) NOT NULL COMMENT '仓库名称',
    `warehouse_type` TINYINT NOT NULL DEFAULT 1 COMMENT '1-平台仓 2-商家仓 3-第三方仓',
    `warehouse_code` VARCHAR(32) NOT NULL DEFAULT '' COMMENT '仓库编码',
    `warehouse_code_uq` VARCHAR(32) GENERATED ALWAYS AS (NULLIF(`warehouse_code`, '')) STORED COMMENT '仓库编码唯一键辅助列（空串视为NULL，未编码仓库不占唯一键）',
    `status` TINYINT NOT NULL DEFAULT 1 COMMENT '1-启用 2-禁用',
    `province` VARCHAR(32) DEFAULT '' COMMENT '省',
    `city` VARCHAR(32) DEFAULT '' COMMENT '市',
    `district` VARCHAR(32) DEFAULT '' COMMENT '区',
    `address` VARCHAR(255) DEFAULT '' COMMENT '详细地址',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    UNIQUE KEY `uk_warehouse_code` (`warehouse_code_uq`),
    KEY `idx_merchant` (`merchant_id`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='仓库表';
