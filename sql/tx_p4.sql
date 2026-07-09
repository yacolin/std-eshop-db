USE eshop_db;

-- ============================================================
-- tx_p4.sql — 物流配送表（依赖 P0: orders, P2: order_items）
-- ============================================================

CREATE TABLE `tx_deliveries` (
    `id` bigint NOT NULL AUTO_INCREMENT COMMENT '物流单ID',
    `delivery_no` varchar(32) NOT NULL COMMENT '物流单号（业务唯一）',
    `order_id` bigint NOT NULL COMMENT '关联 tx_orders.id',
    `order_no` varchar(32) NOT NULL COMMENT '订单号（冗余）',
    `merchant_id` bigint NOT NULL DEFAULT 0 COMMENT '所属商家ID',

    -- 物流商
    `carrier` varchar(20) NOT NULL DEFAULT '' COMMENT '物流商：sf-顺丰 yto-圆通 zto-中通 yunda-韵达 jd-京东物流 other-其他',
    `tracking_no` varchar(64) NOT NULL DEFAULT '' COMMENT '运单号（物流商单号）',

    -- 包裹信息
    `warehouse_id` bigint NOT NULL DEFAULT 0 COMMENT '发货仓库ID',
    `package_count` int NOT NULL DEFAULT 1 COMMENT '包裹数量',

    -- 收货地址快照（下单时地址）
    `consignee` varchar(64) NOT NULL DEFAULT '' COMMENT '收货人',
    `phone` varchar(20) NOT NULL DEFAULT '' COMMENT '联系电话',
    `province` varchar(32) DEFAULT '' COMMENT '省',
    `city` varchar(32) DEFAULT '' COMMENT '市',
    `district` varchar(32) DEFAULT '' COMMENT '区',
    `detail_addr` varchar(256) DEFAULT '' COMMENT '详细地址',

    -- 物流费用
    `shipping_fee` bigint NOT NULL DEFAULT 0 COMMENT '运费（分）',

    -- 状态
    `status` varchar(20) NOT NULL DEFAULT 'pending' COMMENT '物流状态：pending-待发货 picked-已拣货 shipped-已发货 delivering-配送中 delivered-已签收 returned-已退回',

    -- 时间轴
    `shipped_at` datetime(3) DEFAULT NULL COMMENT '发货时间',
    `delivered_at` datetime(3) DEFAULT NULL COMMENT '签收时间',

    -- 审计
    `created_by` varchar(50) DEFAULT '' COMMENT '操作人',
    `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_delivery_no` (`delivery_no`) COMMENT '物流单号唯一',
    KEY `idx_order_id` (`order_id`) COMMENT '按订单查物流',
    KEY `idx_order_no` (`order_no`),
    KEY `idx_merchant` (`merchant_id`),
    KEY `idx_tracking` (`tracking_no`) COMMENT '按运单号查询',
    KEY `idx_status` (`status`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='物流单主表（一个订单可拆多个物流单）';


CREATE TABLE `tx_delivery_items` (
    `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
    `delivery_id` bigint NOT NULL COMMENT '关联 tx_deliveries.id',
    `order_item_id` bigint NOT NULL COMMENT '关联 tx_order_items.id',
    `sku_id` bigint NOT NULL DEFAULT 0 COMMENT 'SKU ID（冗余）',
    `product_name` varchar(200) DEFAULT '' COMMENT '商品名（冗余快照）',
    `quantity` int NOT NULL DEFAULT 1 COMMENT '本次发货数量',
    `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`),
    KEY `idx_delivery_id` (`delivery_id`) COMMENT '按物流单查明细',
    KEY `idx_order_item_id` (`order_item_id`) COMMENT '按订单明细查发货记录',
    KEY `idx_sku_id` (`sku_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='物流发货明细（订单项与包裹的映射）';


CREATE TABLE `tx_delivery_traces` (
    `id` bigint NOT NULL AUTO_INCREMENT COMMENT '轨迹ID',
    `delivery_id` bigint NOT NULL COMMENT '关联 tx_deliveries.id',
    `tracking_no` varchar(64) NOT NULL DEFAULT '' COMMENT '运单号（冗余，方便直接查）',

    `trace_time` datetime(3) NOT NULL COMMENT '轨迹发生时间',
    `location` varchar(200) DEFAULT '' COMMENT '轨迹地点（如：深圳分拨中心）',
    `status` varchar(50) NOT NULL COMMENT '轨迹节点（如：已揽收、已到达分拨中心、派送中）',
    `description` varchar(500) DEFAULT '' COMMENT '轨迹描述（如：快件已到达深圳分拨中心）',

    `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`, `trace_time`),
    KEY `idx_delivery_id` (`delivery_id`) COMMENT '按物流单查轨迹',
    KEY `idx_tracking_no` (`tracking_no`) COMMENT '按运单号查轨迹',
    KEY `idx_trace_time` (`trace_time`) COMMENT '按时间排序轨迹'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='物流轨迹表（物流商回传的节点信息）';
