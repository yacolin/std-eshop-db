USE eshop_db;

-- ============================================================
-- mch_p2.sql — 商户结算明细（依赖 P1: settlement_logs）
-- ============================================================

CREATE TABLE `mch_settlement_details` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `merchant_id` BIGINT NOT NULL COMMENT '商家ID',
    `order_id` BIGINT NOT NULL COMMENT '订单ID',
    `settlement_log_id` BIGINT NOT NULL COMMENT '结算流水ID',
    `order_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '订单实付金额',
    `commission_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '平台佣金',
    `settlement_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '应结算金额',
    `refund_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '退款冲减金额',
    `status` TINYINT NOT NULL DEFAULT 0 COMMENT '0-待结算 1-已结算 2-已冲减',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` DATETIME DEFAULT NULL,
    KEY `idx_merchant_order` (`merchant_id`, `order_id`),
    KEY `idx_settlement_log` (`settlement_log_id`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商家结算明细表';
