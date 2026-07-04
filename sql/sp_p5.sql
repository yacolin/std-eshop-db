USE eshop_db;

-- ============================================================
-- sp_p5.sql — 商品历史版本表（依赖 P1: products）
-- ============================================================

CREATE TABLE `sp_product_versions` (
    `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
    `product_id` bigint NOT NULL COMMENT '关联 sp_products.id',
    `version` int NOT NULL COMMENT '版本号（从1递增）',

    -- 变更内容
    `diff` json NOT NULL COMMENT '变更JSON（{"before": {...}, "after": {...}}）',

    -- 变更摘要
    `changed_fields` json DEFAULT NULL COMMENT '变更字段列表（如：["name", "price", "status"]）',

    -- 操作人
    `operator` varchar(50) DEFAULT '' COMMENT '操作人',
    `operator_id` bigint DEFAULT 0 COMMENT '操作人ID',

    -- 审计
    `reason` varchar(500) DEFAULT '' COMMENT '变更原因',
    `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`),
    KEY `idx_product_id` (`product_id`, `version` DESC) COMMENT '按商品查版本列表',
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品SPU编辑历史版本表（每次编辑记录diff，保留最近10个版本）';
