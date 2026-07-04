USE eshop_db;

-- ============================================================
-- tx_p0.sql — 交易域核心表
-- ============================================================

CREATE TABLE `tx_carts` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '购物车ID',
  `user_id` bigint NOT NULL COMMENT '用户ID（已登录用户）',
  `session_id` varchar(64) DEFAULT '' COMMENT '会话ID（未登录时的临时标识）',
  `item_count` int NOT NULL DEFAULT 0 COMMENT '商品种类数',
  `total_amount` bigint NOT NULL DEFAULT 0 COMMENT '总金额（分，聚合，减少查SKU次数）',
  `expired_at` datetime(3) DEFAULT NULL COMMENT '过期时间（session 型购物车自动清理）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`) COMMENT '按用户查询购物车',
  KEY `idx_session_id` (`session_id`) COMMENT '按会话查询购物车',
  KEY `idx_expired_at` (`expired_at`) COMMENT '清理过期购物车'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='购物车主表（session型购物车30天过期，用户型购物车90天未更新自动清理，每日定时任务扫描 expired_at）';


CREATE TABLE `tx_orders` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `order_no` varchar(32) NOT NULL COMMENT '订单号（业务唯一键，如 202612010001）',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `merchant_id` bigint NOT NULL DEFAULT 0 COMMENT '所属商家ID',

  -- 金额
  `total_amount` bigint NOT NULL DEFAULT 0 COMMENT '商品总金额（分）',
  `discount_amount` bigint NOT NULL DEFAULT 0 COMMENT '优惠金额（分，含优惠券/满减）',
  `shipping_fee` bigint NOT NULL DEFAULT 0 COMMENT '运费（分）',
  `pay_amount` bigint NOT NULL DEFAULT 0 COMMENT '实付金额（分 = total - discount + shipping）',

  -- 状态
  `status` varchar(20) NOT NULL DEFAULT 'pending' COMMENT '订单状态：pending-待支付 confirmed-已确认 paid-已支付 shipped-已发货 delivered-已签收 completed-已完成 cancelled-已取消 closed-已关闭 refunding-退款中 refunded-已退款',
  `payment_status` varchar(20) NOT NULL DEFAULT 'unpaid' COMMENT '支付状态：unpaid-未支付 paying-支付中 paid-已支付 refunding-退款中 refunded-已退款',
  `payment_method` varchar(32) DEFAULT '' COMMENT '支付方式：wechat-微信 alipay-支付宝 wallet-余额',

  -- 收货地址（下单时快照，地址变更不影响已下单）
  `consignee` varchar(64) NOT NULL DEFAULT '' COMMENT '收货人',
  `phone` varchar(20) NOT NULL DEFAULT '' COMMENT '联系电话',
  `province` varchar(32) DEFAULT '' COMMENT '省',
  `city` varchar(32) DEFAULT '' COMMENT '市',
  `district` varchar(32) DEFAULT '' COMMENT '区',
  `detail_addr` varchar(256) DEFAULT '' COMMENT '详细地址',
  `zip_code` varchar(10) DEFAULT '' COMMENT '邮编',

  -- 营销快照
  `coupon_id` bigint DEFAULT NULL COMMENT '使用的优惠券ID',
  `coupon_snapshot` json DEFAULT NULL COMMENT '优惠券快照（名称/面值等，便于售后追溯）',
  `buyer_remark` varchar(500) DEFAULT '' COMMENT '买家备注',
  `seller_remark` varchar(500) DEFAULT '' COMMENT '卖家备注',

  -- 来源
  `source` varchar(20) NOT NULL DEFAULT 'pc' COMMENT '订单来源：pc-电脑端 app-APP miniapp-小程序 h5-H5',

  -- 时间轴
  `paid_at` datetime(3) DEFAULT NULL COMMENT '支付时间',
  `shipped_at` datetime(3) DEFAULT NULL COMMENT '发货时间',
  `delivered_at` datetime(3) DEFAULT NULL COMMENT '签收时间',
  `completed_at` datetime(3) DEFAULT NULL COMMENT '完成时间',
  `closed_at` datetime(3) DEFAULT NULL COMMENT '关闭时间',

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`) COMMENT '订单号唯一',
  KEY `idx_merchant` (`merchant_id`),
  KEY `idx_user_id` (`user_id`, `status`) COMMENT '用户订单列表',
  KEY `idx_status` (`status`) COMMENT '按状态批量查询',
  KEY `idx_payment_status` (`payment_status`),
  KEY `idx_created_at` (`created_at`) COMMENT '按时间查询',
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单主表';
