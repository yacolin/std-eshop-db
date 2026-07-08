USE eshop_db;

-- ============================================================
-- mch_p0.sql — 商户域基础表
-- ============================================================

CREATE TABLE `mch_merchants` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '商家ID',
    `merchant_name` VARCHAR(100) NOT NULL COMMENT '商家名称（店铺名）',
    `merchant_code` VARCHAR(50) UNIQUE NOT NULL COMMENT '商家编码（系统生成，唯一）',

    -- 商家类型
    `merchant_type` TINYINT DEFAULT 1 COMMENT '1-个人商家 2-企业商家 3-品牌直营',
    `merchant_level` TINYINT DEFAULT 1 COMMENT '商家等级 1-普通 2-银牌 3-金牌 4-钻石（影响佣金率/权限）',

    -- 经营信息
    `business_scope` VARCHAR(200) COMMENT '经营范围',
    `business_years` INT DEFAULT 0 COMMENT '经营年限（入驻年限）',

    -- 联系信息（冗余主联系人，便于列表展示）
    `contact_person` VARCHAR(50) COMMENT '主要联系人',
    `contact_phone` VARCHAR(20) COMMENT '联系电话',
    `contact_email` VARCHAR(100) COMMENT '联系邮箱',

    -- 店铺形象
    `logo_url` VARCHAR(500) COMMENT '店铺Logo',
    `banner_url` VARCHAR(500) COMMENT '店铺Banner图',
    `shop_description` TEXT COMMENT '店铺简介',

    -- 状态管理
    `status` TINYINT DEFAULT 0 COMMENT '0-待审核 1-正常 2-冻结 3-已注销',
    `audit_status` TINYINT DEFAULT 0 COMMENT '0-待审核 1-审核通过 2-审核拒绝',
    `audit_reason` VARCHAR(200) COMMENT '审核拒绝原因',
    `audited_at` datetime(3) COMMENT '审核时间',
    `frozen_reason` VARCHAR(200) COMMENT '冻结原因',

    -- 结算配置
    `commission_rate` bigint NOT NULL DEFAULT 0 COMMENT '平台抽佣比例（千分比，如 50 表示5%）',
    `settlement_cycle` TINYINT DEFAULT 1 COMMENT '结算周期 1-T+1 2-T+7 3-月结',

    -- 统计（冗余，提升性能）
    `total_orders` INT DEFAULT 0 COMMENT '历史总订单数',
    `total_sales` bigint NOT NULL DEFAULT 0 COMMENT '历史总销售额（分）',
    `avg_rating` DECIMAL(2,1) DEFAULT 0.0 COMMENT '店铺平均评分',
    `product_count` INT DEFAULT 0 COMMENT '在售商品数量',

    -- 入驻信息
    `settled_at` datetime(3) COMMENT '入驻时间',
    `expire_at` datetime(3) COMMENT '合同到期时间',

    -- 审计字段
    `created_by` BIGINT COMMENT '创建人',
    `updated_by` BIGINT COMMENT '更新人',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,

    INDEX `idx_name` (`merchant_name`),
    INDEX `idx_code` (`merchant_code`),
    INDEX `idx_status_level` (`status`, `merchant_level`),
    INDEX `idx_settled` (`settled_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商家主表';


CREATE TABLE `mch_merchant_contacts` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID',
    `contact_name` VARCHAR(50) NOT NULL COMMENT '联系人姓名',
    `contact_phone` VARCHAR(20) NOT NULL COMMENT '联系电话',
    `contact_role` VARCHAR(30) COMMENT '联系人角色：finance-财务 legal-法人 operation-运营',
    `is_primary` TINYINT DEFAULT 0 COMMENT '是否主要联系人 0-否 1-是',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商家联系人表';


CREATE TABLE `mch_merchant_bank_accounts` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID',
    `bank_name` VARCHAR(100) NOT NULL COMMENT '开户行',
    `bank_branch` VARCHAR(100) COMMENT '开户支行',
    `account_name` VARCHAR(100) NOT NULL COMMENT '开户名',
    `account_no` VARCHAR(50) NOT NULL COMMENT '银行账号',
    `account_type` TINYINT DEFAULT 1 COMMENT '1-对公账户 2-对私账户',
    `is_default` TINYINT DEFAULT NULL COMMENT '是否默认结算账户（NULL=非默认, 1=默认）',
    `status` TINYINT DEFAULT 1 COMMENT '1-正常 2-禁用',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    INDEX `idx_merchant` (`merchant_id`),
    UNIQUE KEY `uk_merchant_default` (`merchant_id`, `is_default`) COMMENT '确保每个商家只有一个默认结算账户（NULL不参与唯一约束）',
    INDEX `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商家结算银行账户表';


CREATE TABLE `mch_merchant_qualifications` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID',
    `qualification_type` VARCHAR(50) NOT NULL COMMENT '资质类型：business_license-营业执照 food-食品经营许可 brand_authorization-品牌授权',
    `qualification_name` VARCHAR(200) NOT NULL COMMENT '资质名称',
    `file_url` VARCHAR(500) NOT NULL COMMENT '资质文件URL',
    `expire_at` datetime(3) COMMENT '有效期',
    `status` TINYINT DEFAULT 0 COMMENT '0-待审核 1-审核通过 2-已过期 3-审核拒绝',
    `audit_remark` VARCHAR(200) COMMENT '审核备注',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_expire` (`expire_at`),
    INDEX `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商家资质表';


-- ==================== 商家域角色 ====================

CREATE TABLE `mch_roles` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID（0=平台预置角色）',
    `name` VARCHAR(50) NOT NULL COMMENT '角色名称（如店长/运营/财务）',
    `display_name` VARCHAR(100) NOT NULL DEFAULT '' COMMENT '角色显示名称',
    `description` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '角色描述',
    `role_type` VARCHAR(20) NOT NULL DEFAULT 'custom' COMMENT 'builtin-系统预置 custom-商家自定义',
    `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序值',
    `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1-启用 0-禁用',
    `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_type` (`role_type`),
    INDEX `idx_status` (`status`),
    INDEX `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商家角色定义表（与平台RBAC隔离）';
