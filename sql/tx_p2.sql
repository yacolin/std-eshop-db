USE eshop_db;

-- ============================================================
-- tx_p2.sql — 支付退款相关表（依赖 P0: orders）
-- ============================================================

CREATE TABLE `tx_payments` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '支付单ID',
  `payment_no` varchar(32) NOT NULL COMMENT '支付单号（业务唯一键）',
  `order_no` varchar(32) NOT NULL COMMENT '关联订单号',
  `order_id` bigint NOT NULL COMMENT '关联 tx_orders.id',
  `merchant_id` bigint NOT NULL DEFAULT 0 COMMENT '所属商家ID',
  `order_type` varchar(20) NOT NULL DEFAULT 'order' COMMENT '订单类型：order-普通订单 flash-秒杀订单',

  `amount` bigint NOT NULL COMMENT '支付金额（分）',
  `currency` varchar(10) NOT NULL DEFAULT 'CNY',

  `payment_method` varchar(32) NOT NULL COMMENT '支付方式：wechat-微信 alipay-支付宝 wallet-余额',
  `channel` varchar(32) DEFAULT '' COMMENT '支付渠道（如 wechat_native-微信 native alipay_page-支付宝页面）',
  `trade_type` varchar(32) DEFAULT '' COMMENT '交易类型：native-jsapi-app-h5-page',
  `transaction_id` varchar(128) DEFAULT NULL COMMENT '支付渠道交易号（微信/支付宝订单号，用于对账）',
  `idempotency_key` varchar(64) NOT NULL COMMENT '支付创建幂等键（防重复提交）',

  `status` varchar(20) NOT NULL DEFAULT 'pending' COMMENT '支付状态：pending-待支付 processing-处理中 success-已支付 failed-支付失败 refunding-退款中 refunded-已退款',
  `failure_reason` varchar(500) DEFAULT '' COMMENT '失败原因',

  `client_ip` varchar(50) DEFAULT '' COMMENT '客户端IP',
  `expire_at` datetime(3) DEFAULT NULL COMMENT '支付过期时间',
  `paid_at` datetime(3) DEFAULT NULL COMMENT '支付成功时间',
  `notify_at` datetime(3) DEFAULT NULL COMMENT '最近一次渠道回调时间',
  `channel_response` json DEFAULT NULL COMMENT '渠道最近一次响应/回调摘要',

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_no` (`payment_no`) COMMENT '支付单号唯一',
  UNIQUE KEY `uk_idempotency_key` (`idempotency_key`) COMMENT '幂等键唯一',
  UNIQUE KEY `uk_transaction_id` (`transaction_id`) COMMENT '渠道交易号唯一（NULL表示未生成）',
  KEY `idx_order_no` (`order_no`) COMMENT '按订单查支付记录',
  KEY `idx_status_expire` (`status`, `expire_at`),
  CONSTRAINT `chk_pay_amount_positive` CHECK (`amount` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='支付单表';


CREATE TABLE `tx_payment_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '日志ID',
  `payment_id` bigint NOT NULL COMMENT '关联 tx_payments.id',
  `payment_no` varchar(32) NOT NULL COMMENT '支付单号（冗余）',
  `channel` varchar(32) DEFAULT '' COMMENT '支付渠道',
  `transaction_id` varchar(128) DEFAULT '' COMMENT '渠道交易号',
  `action` varchar(30) NOT NULL COMMENT '操作类型：create-创建 pay-支付回调 refund-退款 refund_callback-退款回调 close-关闭',
  `request_body` text COMMENT '请求参数（渠道原始数据，用于对账排查）',
  `response_body` text COMMENT '响应结果（渠道原始数据）',
  `status` varchar(20) DEFAULT '' COMMENT '操作结果状态',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_payment_id` (`payment_id`),
  KEY `idx_payment_no` (`payment_no`),
  KEY `idx_transaction_id` (`transaction_id`),
  KEY `idx_action` (`action`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='支付渠道通信日志（对账与排障）';


CREATE TABLE `tx_refunds` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '退款单ID',
  `refund_no` varchar(32) NOT NULL COMMENT '退款单号（业务唯一键）',
  `payment_id` bigint NOT NULL COMMENT '关联 tx_payments.id',
  `payment_no` varchar(32) NOT NULL COMMENT '关联支付单号',
  `order_no` varchar(32) NOT NULL COMMENT '关联订单号',
  `order_id` bigint NOT NULL COMMENT '关联 tx_orders.id',
  `merchant_id` bigint NOT NULL DEFAULT 0 COMMENT '所属商家ID',

  `amount` bigint NOT NULL COMMENT '退款金额（分）',
  `reason` varchar(500) DEFAULT '' COMMENT '退款原因',
  `status` varchar(20) NOT NULL DEFAULT 'pending' COMMENT '退款状态：pending-待处理 processing-处理中 success-已退款 failed-退款失败 rejected-已拒绝',
  `channel_refund_id` varchar(128) DEFAULT NULL COMMENT '渠道退款交易号',
  `failure_reason` varchar(500) DEFAULT '' COMMENT '失败原因',
  `channel_response` json DEFAULT NULL COMMENT '渠道退款响应/回调摘要',
  `idempotency_key` varchar(64) NOT NULL COMMENT '退款幂等键',

  `applied_at` datetime(3) DEFAULT NULL COMMENT '申请时间',
  `success_at` datetime(3) DEFAULT NULL COMMENT '退款成功时间',
  `notify_at` datetime(3) DEFAULT NULL COMMENT '最近一次退款回调时间',

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_refund_no` (`refund_no`) COMMENT '退款单号唯一',
  UNIQUE KEY `uk_channel_refund_id` (`channel_refund_id`) COMMENT '渠道退款号唯一（NULL表示未生成）',
  UNIQUE KEY `uk_idempotency_key` (`idempotency_key`),
  KEY `idx_payment_no` (`payment_no`),
  KEY `idx_order_no` (`order_no`),
  CONSTRAINT `chk_refund_amount` CHECK (`amount` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='退款单表';
