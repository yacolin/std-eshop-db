USE eshop_db;

-- ============================================================
-- rev_p0.sql — 评价域核心表
-- ============================================================

CREATE TABLE `rev_reviews` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '评价ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID（冗余，便于查询）',
    `order_id` BIGINT NOT NULL COMMENT '订单ID（校验必须已购）',
    `order_item_id` BIGINT COMMENT '订单明细ID（用于区分同订单多商品）',

    -- 商品关联（支持 SPU 和 SKU 粒度）
    `spu_id` BIGINT NOT NULL COMMENT '商品SPU ID',
    `sku_id` BIGINT COMMENT '商品SKU ID（若评价具体规格则填）',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',

    -- 评分（按需扩展维度）
    `overall_rating` TINYINT NOT NULL COMMENT '总体评分（1-5星）',
    `quality_rating` TINYINT COMMENT '质量评分（1-5）',
    `logistics_rating` TINYINT COMMENT '物流评分（1-5）',
    `service_rating` TINYINT COMMENT '服务评分（1-5）',

    -- 内容
    `content` TEXT COMMENT '评价文字内容',
    `is_anonymous` TINYINT DEFAULT 0 COMMENT '是否匿名 0-否 1-是',

    -- 审核状态
    `status` TINYINT DEFAULT 0 COMMENT '0-待审核 1-审核通过 2-审核拒绝 3-用户删除',
    `reject_reason` VARCHAR(200) COMMENT '拒绝原因（审核不通过时填写）',

    -- 商家回复关联（冗余最新回复，便于列表展示）
    `latest_reply_id` BIGINT COMMENT '最新回复ID',
    `reply_count` INT DEFAULT 0 COMMENT '回复总数',

    -- 互动数据（冗余提升性能）
    `like_count` INT DEFAULT 0 COMMENT '点赞数',
    `helpful_count` INT DEFAULT 0 COMMENT '有用数',

    -- 审计
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL COMMENT '软删除',

    INDEX `idx_user` (`user_id`),
    INDEX `idx_order` (`order_id`),
    INDEX `idx_spu` (`spu_id`),
    INDEX `idx_sku` (`sku_id`),
    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_status_created` (`status`, `created_at`),
    INDEX `idx_rating` (`overall_rating`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价主表';
