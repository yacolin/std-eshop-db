USE eshop_db;

-- ============================================================
-- tx_p3.sql — 售后相关表（MCH 多商户扩展，依赖 P0: orders）
-- ============================================================

CREATE TABLE `tx_after_sales` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `after_sale_no` VARCHAR(32) NOT NULL COMMENT '售后单号',
    `order_id` BIGINT NOT NULL COMMENT '订单ID',
    `order_item_id` BIGINT NOT NULL COMMENT '订单明细ID',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `after_sale_type` TINYINT NOT NULL COMMENT '1-退款 2-退货 3-换货',
    `apply_quantity` INT NOT NULL DEFAULT 1 COMMENT '申请售后数量',
    `reason` VARCHAR(500) DEFAULT '' COMMENT '申请原因',
    `amount` bigint NOT NULL DEFAULT 0 COMMENT '退款金额（分）',
    `refund_id` BIGINT DEFAULT NULL COMMENT '关联退款单ID',
    `refund_no` VARCHAR(32) DEFAULT '' COMMENT '关联退款单号',
    `status` TINYINT NOT NULL DEFAULT 0 COMMENT '0-待处理 1-审核通过 2-处理中 3-已完成 4-已拒绝 5-平台介入',
    `return_carrier` VARCHAR(20) DEFAULT '' COMMENT '退货物流商',
    `return_tracking_no` VARCHAR(64) DEFAULT '' COMMENT '退货运单号',
    `return_shipped_at` datetime(3) DEFAULT NULL COMMENT '买家退货发出时间',
    `merchant_received_at` datetime(3) DEFAULT NULL COMMENT '商家收货时间',
    `apply_at` datetime(3) DEFAULT NULL COMMENT '申请时间',
    `audited_at` datetime(3) DEFAULT NULL COMMENT '审核时间',
    `completed_at` datetime(3) DEFAULT NULL COMMENT '完成时间',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,
    UNIQUE KEY `uk_after_sale_no` (`after_sale_no`),
    CONSTRAINT `fk_tx_after_sales_refund` FOREIGN KEY (`refund_id`) REFERENCES `tx_refunds` (`id`),
    KEY `idx_order` (`order_id`),
    KEY `idx_order_item` (`order_item_id`),
    KEY `idx_refund` (`refund_id`),
    KEY `idx_merchant_status` (`merchant_id`, `status`),
    KEY `idx_user` (`user_id`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='售后单表';


CREATE TABLE `tx_after_sale_evidences` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `after_sale_id` BIGINT NOT NULL COMMENT '售后单ID',
    `media_type` TINYINT NOT NULL DEFAULT 1 COMMENT '1-图片 2-视频',
    `media_url` VARCHAR(500) NOT NULL COMMENT '凭证URL',
    `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    KEY `idx_after_sale` (`after_sale_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='售后凭证表';


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
