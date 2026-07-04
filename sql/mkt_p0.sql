USE eshop_db;

-- ============================================================
-- mkt_p0.sql — 营销域核心表
-- ============================================================

CREATE TABLE `mkt_promotions` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '促销ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID（0表示平台级活动）',
    `promo_name` VARCHAR(100) NOT NULL COMMENT '活动名称',
    `promo_type` TINYINT NOT NULL COMMENT '1-满减券 2-折扣券 3-秒杀 4-满额减 5-满件折 6-会员价',
    `promo_code` VARCHAR(50) UNIQUE COMMENT '优惠码（优惠券专用）',

    -- 时间范围
    `start_time` datetime(3) NOT NULL COMMENT '开始时间',
    `end_time` datetime(3) NOT NULL COMMENT '结束时间',

    -- 库存限制
    `total_quantity` INT DEFAULT 0 COMMENT '发行总量（0表示不限）',
    `per_user_limit` INT DEFAULT 1 COMMENT '每人限领/限购数量',
    `used_quantity` INT DEFAULT 0 COMMENT '已使用/已售数量',

    -- 规则引用
    `rule_id` BIGINT COMMENT '关联规则表（mkt_promotion_rules）',

    -- 状态
    `status` TINYINT DEFAULT 1 COMMENT '1-草稿 2-生效中 3-已结束 4-已作废',

    -- 审计字段
    `created_by` BIGINT COMMENT '创建人',
    `updated_by` BIGINT COMMENT '更新人',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    `deleted_at` datetime(3) DEFAULT NULL COMMENT '软删除时间',

    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_time` (`start_time`, `end_time`),
    INDEX `idx_type` (`promo_type`),
    INDEX `idx_code` (`promo_code`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='统一促销活动表';
