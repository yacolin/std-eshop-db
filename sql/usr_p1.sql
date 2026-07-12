USE eshop_db;

-- ============================================================
-- usr_p2.sql — 用户等级与积分体系（依赖 P0: users）
-- ============================================================

CREATE TABLE `usr_levels` (
    `id` bigint NOT NULL AUTO_INCREMENT COMMENT '等级ID',
    `name` varchar(50) NOT NULL COMMENT '等级名称（如：青铜会员、白银会员、黄金会员、钻石会员）',
    `level` int NOT NULL COMMENT '等级数值（1=青铜 2=白银 3=黄金 4=钻石）',
    `icon` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '等级图标URL',

    -- 门槛（通过 min_points 与用户累计积分动态比较确定等级）
    `min_points` bigint NOT NULL DEFAULT 0 COMMENT '该等级所需最低累计积分',

    -- 权益
    `discount_rate` bigint NOT NULL DEFAULT 100 COMMENT '折扣率（千分比，1000=无折扣，900=九折）',
    `free_shipping` tinyint NOT NULL DEFAULT 0 COMMENT '1-免运费',
    `points_multiplier` decimal(3,2) NOT NULL DEFAULT 1.00 COMMENT '消费积分倍数（如 1.5 倍积分）',

    -- 其他权益（JSON 扩展）
    `benefits` json DEFAULT NULL COMMENT '扩展权益JSON（如：{"birthday_gift": true, "exclusive_coupon": true}）',

    -- 审计
    `status` tinyint NOT NULL DEFAULT 1 COMMENT '1-启用 0-禁用',
    `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序',
    `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_level` (`level`),
    KEY `idx_status` (`status`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户等级定义表';



CREATE TABLE `usr_level_rules` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '规则名称',
  `rule_type` varchar(20) NOT NULL DEFAULT '' COMMENT '规则类型：upgrade-自动升级 downgrade-自动降级',
  `from_level_id` bigint NOT NULL DEFAULT '0' COMMENT '源等级ID（0=任意等级）',
  `to_level_id` bigint NOT NULL DEFAULT '0' COMMENT '目标等级ID',
  `condition_type` varchar(50) NOT NULL DEFAULT '' COMMENT '条件类型：points-累计积分 order_count-订单数 order_amount-消费金额',
  `condition_value` bigint NOT NULL DEFAULT '0' COMMENT '条件阈值',
  `description` text COMMENT '规则说明',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序',
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '状态：0-禁用 1-启用',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='等级升降级规则配置';


CREATE TABLE `usr_points` (
    `id` bigint NOT NULL AUTO_INCREMENT COMMENT '流水ID',
    `user_id` bigint NOT NULL COMMENT '用户ID',
    `points` bigint NOT NULL COMMENT '积分变动（正=增加，负=扣减）',
    `balance_after` bigint NOT NULL DEFAULT 0 COMMENT '变动后积分余额',

    -- 来源
    `source` varchar(30) NOT NULL COMMENT '积分来源：order-下单消费 review-评价 signin-签到 admin-管理员调整 refund-退款扣减 expire-过期清零',
    `source_id` varchar(64) DEFAULT '' COMMENT '来源ID（如订单号、评价ID）',

    -- 过期
    `expire_at` datetime(3) DEFAULT NULL COMMENT '过期时间（NULL=永不过期）',

    -- 状态
    `status` tinyint NOT NULL DEFAULT 0 COMMENT '0-待确认 1-已确认 2-已过期 3-已作废',

    -- 审计
    `remark` varchar(200) DEFAULT '' COMMENT '备注',
    `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`) COMMENT '按用户查积分流水',
    KEY `idx_source` (`source`, `source_id`) COMMENT '按来源查询',
    KEY `idx_expire_at` (`expire_at`) COMMENT '定时扫描过期积分',
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户积分流水表';


CREATE TABLE `usr_points_rules` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '规则名称',
  `rule_key` varchar(50) NOT NULL DEFAULT '' COMMENT '规则键名：earn_rate-消费返积分比例 expire_days-积分过期天数 signin_points-签到奖励积分 review_points-评价奖励积分',
  `value_int` int DEFAULT NULL COMMENT '整数值（如积分数量、天数）',
  `value_decimal` decimal(10,2) DEFAULT NULL COMMENT '小数值（如比例、倍数）',
  `value_string` varchar(255) DEFAULT '' COMMENT '字符串值（如配置json、文本）',
  `description` text COMMENT '规则说明',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序',
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '状态：0-禁用 1-启用',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rule_key` (`rule_key`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='积分规则配置';
