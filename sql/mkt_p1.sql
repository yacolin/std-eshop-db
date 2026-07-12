USE eshop_db;

-- ============================================================
-- mkt_p1.sql — 营销关联表（依赖 P0: promotions）
-- ============================================================

CREATE TABLE `mkt_promotion_rules` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '规则ID',
    `promotion_id` BIGINT NOT NULL COMMENT '所属促销ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',
    `rule_name` VARCHAR(100) COMMENT '规则名称',

    -- 触发条件
    `condition_type` TINYINT NOT NULL COMMENT '1-无门槛 2-满金额 3-满件数 4-指定用户等级',
    `condition_value` BIGINT NOT NULL DEFAULT 0 COMMENT '门槛值（分）',

    -- 优惠内容JSON化（支持阶梯）
    `benefit_config` JSON NOT NULL COMMENT '优惠配置JSON。例：{"type":1,"value":3000} 或 {"type":2,"steps":[{"limit":10000,"rate":900},{"limit":20000,"rate":800}]}',

    -- 叠加规则
    `is_stackable` TINYINT DEFAULT 0 COMMENT '是否可与其他促销叠加 0-否 1-是',
    `stack_group` INT DEFAULT 0 COMMENT '叠加组ID（同组内互斥，不同组可叠加）',

    -- 审计字段
    `created_by` BIGINT COMMENT '创建人',
    `updated_by` BIGINT COMMENT '更新人',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` DATETIME(3) DEFAULT NULL,

    PRIMARY KEY (`id`),
    KEY `idx_promotion` (`promotion_id`),
    KEY `idx_stack_group` (`stack_group`, `is_stackable`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='促销规则表（配置化）';


CREATE TABLE `mkt_promotion_products` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `promotion_id` BIGINT NOT NULL COMMENT '促销ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',
    `product_type` TINYINT NOT NULL COMMENT '1-全站 2-指定分类 3-指定SPU 4-指定SKU',
    `target_id` BIGINT COMMENT '目标ID（SPU_ID或SKU_ID或Category_ID）',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `deleted_at` DATETIME(3) DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_promotion_target` (`promotion_id`, `product_type`, `target_id`),
    KEY `idx_target` (`target_id`, `product_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='促销适用商品表';


CREATE TABLE `mkt_user_promotions` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_promotion_no` VARCHAR(32) NOT NULL COMMENT '用户促销资产编号',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `promotion_id` BIGINT NOT NULL COMMENT '促销ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',

    -- 领取/获取信息
    `acquire_time` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) COMMENT '领取时间',
    `expire_time` DATETIME(3) COMMENT '过期时间',

    -- 使用状态
    `status` TINYINT DEFAULT 1 COMMENT '1-未使用 2-锁定中(下单未付) 3-已使用 4-已过期 5-已作废',
    `lock_order_id` BIGINT DEFAULT NULL COMMENT '锁定的订单ID（用于回滚）',
    `used_time` DATETIME(3) COMMENT '使用时间',
    `order_id` BIGINT COMMENT '最终使用的订单ID',

    -- 秒杀专用
    `queue_token` VARCHAR(64) DEFAULT '' COMMENT '秒杀排队令牌',

    -- 审计字段
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` DATETIME(3) DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_promotion_no` (`user_promotion_no`),
    KEY `idx_user_available` (`user_id`, `status`, `expire_time`),
    KEY `idx_promotion` (`promotion_id`),
    KEY `idx_lock_order` (`lock_order_id`),
    KEY `idx_order` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户促销资产表（状态机优化）';


CREATE TABLE `mkt_promotion_stocks` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `promotion_id` BIGINT NOT NULL COMMENT '促销ID',
    `sku_id` BIGINT DEFAULT NULL COMMENT 'SKU ID（秒杀专用，通用活动可为空）',
    `total_stock` INT NOT NULL DEFAULT 0 COMMENT '总库存',
    `available_stock` INT NOT NULL DEFAULT 0 COMMENT '可用库存',
    `locked_stock` INT NOT NULL DEFAULT 0 COMMENT '锁定库存（下单未付）',
    `version` INT NOT NULL DEFAULT 0 COMMENT '乐观锁版本号',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_promotion_sku` (`promotion_id`, `sku_id`),
    CONSTRAINT `chk_stock_positive` CHECK (`available_stock` >= 0 AND `locked_stock` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='促销库存表（支持秒杀）';


CREATE TABLE `mkt_promotion_usage_logs` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `promotion_id` BIGINT NOT NULL COMMENT '促销ID',
    `user_promotion_id` BIGINT DEFAULT NULL COMMENT '用户促销资产ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `order_id` BIGINT NOT NULL COMMENT '使用的订单ID',

    -- 使用信息
    `discount_amount` BIGINT NOT NULL DEFAULT 0 COMMENT '优惠金额（分）',

    -- 快照信息（用于财务对账）
    `promotion_snapshot` JSON DEFAULT NULL COMMENT '优惠快照（名称、规则等）',

    -- 审计字段
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`),
    KEY `idx_order` (`order_id`),
    KEY `idx_promotion_created` (`promotion_id`, `created_at`),
    KEY `idx_user_created` (`user_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='促销使用记录表（建议按 created_at 月度分区）';