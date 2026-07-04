USE eshop_db;

-- ============================================================
-- sp_p4.sql — 仓库表（依赖 P2: skus）
-- ============================================================

CREATE TABLE `sp_warehouses` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '仓库ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID（0表示平台仓）',
    `warehouse_name` VARCHAR(100) NOT NULL COMMENT '仓库名称',
    `warehouse_type` TINYINT NOT NULL DEFAULT 1 COMMENT '1-平台仓 2-商家仓 3-第三方仓',
    `status` TINYINT NOT NULL DEFAULT 1 COMMENT '1-启用 2-禁用',
    `province` VARCHAR(32) DEFAULT '' COMMENT '省',
    `city` VARCHAR(32) DEFAULT '' COMMENT '市',
    `district` VARCHAR(32) DEFAULT '' COMMENT '区',
    `address` VARCHAR(255) DEFAULT '' COMMENT '详细地址',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    KEY `idx_merchant` (`merchant_id`),
    KEY `idx_status` (`status`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='仓库表';
