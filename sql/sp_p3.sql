USE eshop_db;

-- ============================================================
-- sp_p3.sql — 库存相关表（依赖 P2: skus）
-- ============================================================

CREATE TABLE `sp_inventories` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '库存记录ID',
  `sku_id` bigint NOT NULL COMMENT '关联 skus.id',
  `merchant_id` bigint NOT NULL DEFAULT 0 COMMENT '所属商家ID',

  -- 仓库
  `warehouse_id` bigint NOT NULL DEFAULT 0 COMMENT '仓库ID（0表示主仓，未来扩展多仓，关联 warehouse.id）',

  -- 库存数量
  `quantity` bigint NOT NULL DEFAULT 0 COMMENT '物理库存总量（含预占）',
  `reserved` bigint NOT NULL DEFAULT 0 COMMENT '预占库存（下单未支付）',
  `available` bigint GENERATED ALWAYS AS (quantity - reserved) VIRTUAL COMMENT '可售库存（虚拟列，无需持久化）',
  `in_transit` bigint NOT NULL DEFAULT 0 COMMENT '在途库存（采购中/调拨中）',

  -- 安全库存
  `threshold` bigint NOT NULL DEFAULT 10 COMMENT '安全库存预警阈值（低于此值触发告警）',
  `max_threshold` bigint NOT NULL DEFAULT 999999 COMMENT '最大库存上限（入库不能超过此值）',

  -- 状态
  `status` varchar(20) NOT NULL DEFAULT 'instock' COMMENT '库存状态：instock-充足 lowstock-缺货 outofstock-无货',

  -- 盘点审计
  `last_counted_at` datetime DEFAULT NULL COMMENT '最后盘点时间',
  `last_counted_by` varchar(50) DEFAULT '' COMMENT '最后盘点人',

  -- 审计字段
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sku_warehouse` (`sku_id`, `warehouse_id`) COMMENT '同一SKU在同一仓库只有一条库存记录',
  KEY `idx_merchant` (`merchant_id`),
  KEY `idx_sku_status` (`sku_id`, `status`) COMMENT '查询SKU库存状态',
  KEY `idx_warehouse_status` (`warehouse_id`, `status`) COMMENT '按仓库查库存',
  KEY `idx_available` (`available`) COMMENT '按可售库存排序',
  KEY `idx_deleted_at` (`deleted_at`),
  KEY `idx_sku_for_update` (`sku_id`, `warehouse_id`, `status`) COMMENT 'FOR UPDATE 锁定查询'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='库存表（支持多仓库）';


CREATE TABLE `sp_inventory_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '日志ID',
  `sku_id` bigint NOT NULL COMMENT '关联 skus.id',
  `merchant_id` bigint NOT NULL DEFAULT 0 COMMENT '所属商家ID',
  `warehouse_id` bigint NOT NULL DEFAULT 0 COMMENT '仓库ID',
  `change_type` varchar(30) NOT NULL COMMENT '变更类型：order_lock-下单预占 order_unlock-取消释放 order_dedut-支付扣减 inbound-入库 outbound-出库 return-退货入库 adjust-盘盈亏修正',
  `before_quantity` bigint NOT NULL DEFAULT 0 COMMENT '变更前物理库存',
  `after_quantity` bigint NOT NULL DEFAULT 0 COMMENT '变更后物理库存',
  `before_reserved` bigint NOT NULL DEFAULT 0 COMMENT '变更前预占库存',
  `after_reserved` bigint NOT NULL DEFAULT 0 COMMENT '变更后预占库存',
  `change_amount` bigint NOT NULL DEFAULT 0 COMMENT '变更数量（正=增加，负=减少）',
  `reference_id` varchar(64) DEFAULT '' COMMENT '关联单据ID（如订单号、入库单号）',
  `operator` varchar(50) DEFAULT '' COMMENT '操作人（系统操作填 system）',
  `note` varchar(500) DEFAULT '' COMMENT '备注',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_merchant` (`merchant_id`),
  KEY `idx_sku_id` (`sku_id`, `warehouse_id`) COMMENT '按SKU查库存变更历史',
  KEY `idx_change_type` (`change_type`) COMMENT '按变更类型统计',
  KEY `idx_reference_id` (`reference_id`) COMMENT '按关联单据查',
  KEY `idx_created_at` (`created_at`) COMMENT '按时间范围查'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='库存变更流水表（对账与审计）';
