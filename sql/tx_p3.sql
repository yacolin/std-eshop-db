USE eshop_db;

-- ============================================================
-- tx_p3.sql — 售后相关表（MCH 多商户扩展，依赖 P0: orders）
-- ============================================================

CREATE TABLE `tx_after_sales` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `order_id` BIGINT NOT NULL COMMENT '订单ID',
    `order_item_id` BIGINT NOT NULL COMMENT '订单明细ID',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `after_sale_type` TINYINT NOT NULL COMMENT '1-退款 2-退货 3-换货',
    `reason` VARCHAR(500) DEFAULT '' COMMENT '申请原因',
    `amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '退款金额',
    `status` TINYINT NOT NULL DEFAULT 0 COMMENT '0-待处理 1-审核通过 2-处理中 3-已完成 4-已拒绝',
    `apply_at` datetime(3) DEFAULT NULL COMMENT '申请时间',
    `completed_at` datetime(3) DEFAULT NULL COMMENT '完成时间',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    KEY `idx_order` (`order_id`),
    KEY `idx_merchant_status` (`merchant_id`, `status`),
    KEY `idx_user` (`user_id`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='售后单表';


CREATE TABLE `tx_after_sale_logs` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `after_sale_id` BIGINT NOT NULL COMMENT '售后单ID',
    `operator_id` BIGINT NOT NULL DEFAULT 0 COMMENT '操作人ID',
    `operator_type` VARCHAR(20) NOT NULL DEFAULT 'system' COMMENT 'operator/user/merchant/admin',
    `action` VARCHAR(50) NOT NULL COMMENT '动作',
    `remark` VARCHAR(500) DEFAULT '' COMMENT '备注',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    KEY `idx_after_sale` (`after_sale_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='售后流程日志表';
