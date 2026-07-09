USE eshop_db;

-- ============================================================
-- tx_p1.sql — 交易明细与日志表（依赖 P0: orders）
-- ============================================================

CREATE TABLE `tx_cart_items` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '购物车项ID',
  `cart_id` bigint NOT NULL COMMENT '关联 tx_carts.id',
  `sku_id` bigint NOT NULL COMMENT '关联 skus.id(sp_skus)',
  `product_id` bigint NOT NULL DEFAULT 0 COMMENT '关联 products.id(sp_products)，冗余用于展示',
  `product_name` varchar(200) NOT NULL DEFAULT '' COMMENT '商品名（冗余快照）',
  `sku_spec` json DEFAULT NULL COMMENT '规格JSON快照（如{"颜色":"红色","内存":"256G"}）',
  `image` varchar(512) DEFAULT '' COMMENT '商品图（冗余快照）',
  `price` bigint NOT NULL COMMENT '加入时的价格（分，防止下单时价格变动导致纠纷）',
  `quantity` int NOT NULL DEFAULT 1 COMMENT '数量',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_cart_id` (`cart_id`) COMMENT '按购物车查项',
  KEY `idx_sku_id` (`sku_id`) COMMENT '按SKU查询（加购去重）',
  UNIQUE KEY `uk_cart_sku` (`cart_id`, `sku_id`) COMMENT '同一购物车不重复加同一SKU'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='购物车商品项';


CREATE TABLE `tx_order_items` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '订单项ID',
  `order_id` bigint NOT NULL COMMENT '关联 tx_orders.id',
  `sub_order_id` bigint NOT NULL COMMENT '子订单ID',
  `merchant_id` bigint NOT NULL DEFAULT 0 COMMENT '所属商家ID',
  `order_no` varchar(32) NOT NULL COMMENT '订单号（冗余，方便按订单号查）',
  `sub_order_no` varchar(32) NOT NULL DEFAULT '' COMMENT '子订单号（冗余，方便按商家订单查）',

  -- 商品快照（下单时锁定，后续商品信息变更不影响已下单）
  `sku_id` bigint NOT NULL COMMENT '关联 skus.id(sp_skus)',
  `product_id` bigint NOT NULL DEFAULT 0 COMMENT '关联 products.id(sp_products)',
  `sku_code` varchar(100) DEFAULT '' COMMENT '商家编码（冗余快照）',
  `product_name` varchar(200) NOT NULL DEFAULT '' COMMENT '商品名（冗余快照）',
  `sku_spec_summary` varchar(500) DEFAULT '' COMMENT '规格摘要（如：红色 / 256G）',
  `sku_spec` json DEFAULT NULL COMMENT '规格JSON快照',
  `image` varchar(512) DEFAULT '' COMMENT '商品图（冗余快照）',

  -- 价格
  `price` bigint NOT NULL COMMENT '单价（分，下单时价格）',
  `quantity` int NOT NULL DEFAULT 1 COMMENT '购买数量',
  `subtotal` bigint NOT NULL DEFAULT 0 COMMENT '小计（分 = price * quantity）',

  -- 售后
  `refund_status` varchar(20) NOT NULL DEFAULT 'none' COMMENT '退款状态：none-无 refunding-退款中 refunded-已退款',
  `refund_amount` bigint NOT NULL DEFAULT 0 COMMENT '已退款金额（分）',

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  KEY `idx_order_no` (`order_no`),
  KEY `idx_sku_id` (`sku_id`),
  KEY `idx_sub_order_id` (`sub_order_id`),
  CONSTRAINT `chk_subtotal` CHECK (`subtotal` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单明细表';


CREATE TABLE `tx_order_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '日志ID',
  `order_id` bigint NOT NULL COMMENT '关联 tx_orders.id',
  `order_no` varchar(32) NOT NULL COMMENT '订单号（冗余，便于按号查日志）',
  `from_status` varchar(20) DEFAULT '' COMMENT '变更前状态',
  `to_status` varchar(20) NOT NULL COMMENT '变更后状态',
  `operator` varchar(50) DEFAULT 'system' COMMENT '操作人',
  `operator_type` varchar(20) DEFAULT 'system' COMMENT '操作人类型：system-系统 user-用户 admin-管理员',
  `note` varchar(500) DEFAULT '' COMMENT '备注（如：支付成功、超时取消）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单操作日志表（审计与对账）';
