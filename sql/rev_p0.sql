USE eshop_db;

-- ============================================================
-- rev_p0.sql — 评价域核心表
-- ============================================================

CREATE TABLE `rev_reviews` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '评价ID',
    `review_no` VARCHAR(32) NOT NULL COMMENT '评价业务单号（幂等键）',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `order_id` BIGINT NOT NULL COMMENT '订单ID（校验必须已购）',
    `order_item_id` BIGINT NOT NULL COMMENT '订单明细ID（用于区分同订单多商品）',

    -- 商品关联
    `spu_id` BIGINT NOT NULL COMMENT '商品SPU ID',
    `sku_id` BIGINT DEFAULT NULL COMMENT '商品SKU ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',

    -- 评分
    `overall_rating` TINYINT NOT NULL COMMENT '总体评分（1-5星）',
    `quality_rating` TINYINT DEFAULT NULL COMMENT '质量评分',
    `logistics_rating` TINYINT DEFAULT NULL COMMENT '物流评分',
    `service_rating` TINYINT DEFAULT NULL COMMENT '服务评分',

    -- 内容
    `content` TEXT DEFAULT NULL COMMENT '评价文字内容',
    `content_length` SMALLINT DEFAULT 0 COMMENT '内容长度（冗余，用于筛选优质评价）',
    `is_anonymous` TINYINT DEFAULT 0 COMMENT '是否匿名 0-否 1-是',
    `has_media` TINYINT DEFAULT 0 COMMENT '是否包含媒体 0-否 1-是',

    -- 审核与风控
    `status` TINYINT DEFAULT 0 COMMENT '0-待审核 1-审核通过 2-审核拒绝 3-用户删除 4-平台屏蔽',
    `risk_level` TINYINT DEFAULT 0 COMMENT '风险等级 0-正常 1-低风险 2-高风险',
    `reject_reason` VARCHAR(200) DEFAULT NULL COMMENT '拒绝原因',
    `audited_by` BIGINT DEFAULT NULL COMMENT '审核人ID',
    `audited_at` DATETIME(3) DEFAULT NULL COMMENT '审核时间',

    -- 互动数据（仅作展示，实时数据来自Redis）
    `like_count` INT DEFAULT 0 COMMENT '点赞数（异步校准）',
    `helpful_count` INT DEFAULT 0 COMMENT '有用数（异步校准）',
    `reply_count` INT DEFAULT 0 COMMENT '回复总数（异步校准）',

    -- 审计
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_review_no` (`review_no`),
    UNIQUE KEY `uk_order_item` (`order_item_id`),
    KEY `idx_spu_status_created` (`spu_id`, `status`, `created_at`),
    KEY `idx_merchant_status` (`merchant_id`, `status`),
    KEY `idx_user_created` (`user_id`, `created_at`),
    KEY `idx_rating_status` (`overall_rating`, `status`),
    KEY `idx_audited` (`audited_at`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价主表';