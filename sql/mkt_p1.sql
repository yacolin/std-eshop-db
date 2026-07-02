USE eshop_db;

-- ============================================================
-- mkt_p1.sql — 营销关联表（依赖 P0: promotions）
-- ============================================================

CREATE TABLE `mkt_promotion_rules` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '规则ID',
    `promotion_id` BIGINT NOT NULL COMMENT '所属促销ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID（0表示平台级规则）',
    `rule_name` VARCHAR(100) COMMENT '规则名称（便于理解）',

    -- 触发条件
    `condition_type` TINYINT NOT NULL COMMENT '1-无门槛 2-满金额 3-满件数 4-指定用户等级',
    `condition_value` DECIMAL(10,2) COMMENT '门槛值（满200则存200.00）',

    -- 优惠内容
    `benefit_type` TINYINT NOT NULL COMMENT '1-减固定金额 2-打折扣 3-赠品 4-免运费 5-送积分',
    `benefit_value` DECIMAL(10,2) COMMENT '优惠值（减30或打8折则存30/0.8）',

    -- 叠加规则
    `is_stackable` TINYINT DEFAULT 0 COMMENT '是否可与其他促销叠加 0-否 1-是',
    `stack_priority` INT DEFAULT 0 COMMENT '叠加优先级（数字越小越优先计算）',

    -- 审计字段
    `created_by` BIGINT COMMENT '创建人',
    `updated_by` BIGINT COMMENT '更新人',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted_at` DATETIME DEFAULT NULL COMMENT '软删除时间',

    INDEX `idx_promotion` (`promotion_id`),
    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_stack` (`is_stackable`, `stack_priority`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='促销规则表';


CREATE TABLE `mkt_promotion_products` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    `promotion_id` BIGINT NOT NULL COMMENT '促销ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',
    `product_id` BIGINT NOT NULL COMMENT '商品SPU ID',
    `sku_id` BIGINT DEFAULT NULL COMMENT '限制到SKU维度则填写（NULL表示整个SPU）',
    `status` TINYINT DEFAULT 1 COMMENT '1-参与活动 0-取消参与',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `deleted_at` DATETIME DEFAULT NULL,

    UNIQUE KEY `uk_promo_product_sku` (`promotion_id`, `product_id`, `sku_id`),
    INDEX `idx_product` (`product_id`),
    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='促销商品关联表';


CREATE TABLE `mkt_user_promotions` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `promotion_id` BIGINT NOT NULL COMMENT '促销ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',

    -- 领取/获取信息
    `acquire_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '领取时间',
    `expire_time` DATETIME COMMENT '过期时间（优惠券必填）',

    -- 使用状态
    `status` TINYINT DEFAULT 1 COMMENT '1-未使用 2-已使用 3-已过期 4-已作废',
    `used_time` DATETIME COMMENT '使用时间',
    `order_id` BIGINT COMMENT '使用的订单ID',

    -- 秒杀专用
    `queue_token` VARCHAR(64) COMMENT '秒杀排队令牌',

    -- 审计字段
    `created_by` BIGINT COMMENT '创建人',
    `updated_by` BIGINT COMMENT '更新人',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted_at` DATETIME DEFAULT NULL COMMENT '软删除时间',

    INDEX `idx_user` (`user_id`),
    INDEX `idx_promotion` (`promotion_id`),
    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_status_expire` (`status`, `expire_time`),
    INDEX `idx_order` (`order_id`),
    UNIQUE KEY `uk_user_promo` (`user_id`, `promotion_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户促销资产表';


CREATE TABLE `mkt_promotion_usage_logs` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    `promotion_id` BIGINT NOT NULL COMMENT '促销ID',
    `user_promotion_id` BIGINT DEFAULT NULL COMMENT '用户促销资产ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',
    `order_id` BIGINT DEFAULT NULL COMMENT '使用的订单ID',

    -- 使用信息
    `usage_type` TINYINT DEFAULT 1 COMMENT '1-下单使用 2-自动优惠',
    `discount_amount` DECIMAL(10,2) DEFAULT 0.00 COMMENT '优惠金额',

    -- 审计字段
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,

    INDEX `idx_promotion` (`promotion_id`),
    INDEX `idx_user` (`user_id`),
    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_order` (`order_id`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='促销使用记录表';
