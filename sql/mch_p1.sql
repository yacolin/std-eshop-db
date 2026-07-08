USE eshop_db;

-- ============================================================
-- mch_p1.sql — 商户运营相关表（依赖 P0: merchants）
-- ============================================================

-- 商家-员工关联表：指向 sys_staff（B端员工），非 C端消费者
CREATE TABLE `mch_merchant_users` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID',
    `staff_id` BIGINT NOT NULL COMMENT '员工ID（关联 sys_staff.id）',
    `role_id` BIGINT NOT NULL DEFAULT 0 COMMENT '商家角色ID（关联 mch_merchant_roles.id，与平台RBAC隔离）',
    `status` TINYINT NOT NULL DEFAULT 1 COMMENT '1-正常 2-禁用',
    `invited_at` datetime(3) DEFAULT NULL COMMENT '邀请时间',
    `last_login_at` datetime(3) DEFAULT NULL COMMENT '最后登录时间',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    UNIQUE KEY `uk_merchant_staff` (`merchant_id`, `staff_id`),
    KEY `idx_merchant_status` (`merchant_id`, `status`),
    KEY `idx_staff_id` (`staff_id`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商家-员工关联表（B端员工通过此表绑定商户）';


CREATE TABLE `mch_merchant_balances` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID',
    `available_balance` bigint NOT NULL DEFAULT 0 COMMENT '可提现余额（分）',
    `freeze_balance` bigint NOT NULL DEFAULT 0 COMMENT '冻结余额（分）',
    `currency` VARCHAR(10) NOT NULL DEFAULT 'CNY' COMMENT '币种',
    `version` BIGINT NOT NULL DEFAULT 0 COMMENT '版本号（并发控制）',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    UNIQUE KEY `uk_merchant_currency` (`merchant_id`, `currency`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商家资金余额表';


CREATE TABLE `mch_merchant_withdrawals` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID',
    `withdraw_no` VARCHAR(32) NOT NULL COMMENT '提现单号',
    `amount` bigint NOT NULL COMMENT '提现金额（分）',
    `bank_account_id` BIGINT NOT NULL COMMENT '结算账户ID',
    `status` TINYINT NOT NULL DEFAULT 0 COMMENT '0-待审核 1-审核通过 2-已打款 3-拒绝',
    `audit_remark` VARCHAR(200) DEFAULT '' COMMENT '审批备注',
    `applied_at` datetime(3) DEFAULT NULL COMMENT '申请时间',
    `approved_at` datetime(3) DEFAULT NULL COMMENT '审批时间',
    `paid_at` datetime(3) DEFAULT NULL COMMENT '打款时间',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    UNIQUE KEY `uk_withdraw_no` (`withdraw_no`),
    KEY `idx_merchant_status` (`merchant_id`, `status`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商家提现申请表';


CREATE TABLE `mch_merchant_settlement_logs` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID',
    `settlement_no` VARCHAR(32) NOT NULL COMMENT '结算单号',
    `settlement_cycle` VARCHAR(20) COMMENT '结算周期（如 2026-07-01~2026-07-15）',
    `total_amount` bigint NOT NULL DEFAULT 0 COMMENT '期内总金额（分）',
    `commission_amount` bigint NOT NULL DEFAULT 0 COMMENT '平台佣金（分）',
    `settlement_amount` bigint NOT NULL DEFAULT 0 COMMENT '应结算金额（分）',
    `status` TINYINT DEFAULT 0 COMMENT '0-待结算 1-已结算 2-已打款',
    `settled_at` datetime(3) COMMENT '结算时间',
    `paid_at` datetime(3) COMMENT '打款时间',
    `remark` VARCHAR(500) COMMENT '备注',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    UNIQUE KEY `uk_settlement_no` (`settlement_no`),
    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_status` (`status`),
    INDEX `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商家结算流水表';


-- ==================== 商家角色-权限关联 ====================

CREATE TABLE `mch_merchant_role_permissions` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID',
    `role_id` BIGINT NOT NULL COMMENT '角色ID（关联 mch_merchant_roles.id）',
    `permission_name` VARCHAR(100) NOT NULL COMMENT '权限标识（对应 sys_permissions.name）',
    `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    UNIQUE KEY `uk_role_permission` (`role_id`, `permission_name`),
    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_permission` (`permission_name`),
    INDEX `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商家角色-权限关联表（基于平台权限标识）';
