USE eshop_db;

-- ============================================================
-- mkt_p0.sql — 营销域核心表
-- ============================================================

CREATE TABLE `mkt_promotions` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '促销ID',
    `promotion_no` VARCHAR(32) NOT NULL COMMENT '促销业务编号',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID（0表示平台级活动）',
    `promo_name` VARCHAR(100) NOT NULL COMMENT '活动名称',
    `promo_type` TINYINT NOT NULL COMMENT '1-满减券 2-折扣券 3-秒杀 4-满额减 5-满件折 6-会员价',
    `promo_code` VARCHAR(50) DEFAULT '' COMMENT '优惠码（优惠券专用）',

    -- 时间范围
    `start_time` DATETIME(3) NOT NULL COMMENT '开始时间',
    `end_time` DATETIME(3) NOT NULL COMMENT '结束时间',

    -- 库存限制
    `total_quantity` INT DEFAULT 0 COMMENT '发行总量（0表示不限）',
    `per_user_limit` INT DEFAULT 1 COMMENT '每人限领/限购数量',
    `used_quantity` INT DEFAULT 0 COMMENT '已使用/已售数量（异步统计，非实时）',

    -- 规则引用
    `rule_id` BIGINT NOT NULL DEFAULT 0 COMMENT '关联规则表ID',

    -- 状态
    `status` TINYINT DEFAULT 1 COMMENT '1-草稿 2-待生效 3-生效中 4-已暂停 5-已结束 6-已作废',

    -- 优先级（用于叠加计算）
    `priority` INT DEFAULT 0 COMMENT '优先级（数字越大越优先，同类型互斥）',

    -- 审计字段
    `created_by` BIGINT COMMENT '创建人',
    `updated_by` BIGINT COMMENT '更新人',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` DATETIME(3) DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_promotion_no` (`promotion_no`),
    KEY `uk_promo_code` (`promo_code`),
    KEY `idx_merchant_status_time` (`merchant_id`, `status`, `start_time`, `end_time`),
    KEY `idx_type_status` (`promo_type`, `status`),
    KEY `idx_rule_id` (`rule_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='统一促销活动表';