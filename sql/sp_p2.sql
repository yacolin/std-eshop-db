USE eshop_db;

-- ============================================================
-- sp_p2.sql — 商品域关联业务表（依赖 P1）
-- ============================================================

CREATE TABLE `sp_category_brands` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `category_id` bigint NOT NULL COMMENT '关联 categories.id',
  `brand_id` bigint NOT NULL COMMENT '关联 brands.id',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序权重（越小越靠前，控制该类目下品牌的展示顺序）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_category_brand` (`category_id`, `brand_id`) COMMENT '同一类目下不重复关联同一品牌',
  KEY `idx_brand_id` (`brand_id`) COMMENT '查品牌覆盖了哪些类目'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='类目-品牌关联表（多对多）';


CREATE TABLE `sp_skus` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'SKU ID',
  `product_id` bigint NOT NULL COMMENT '关联 products.id',
  `merchant_id` bigint NOT NULL DEFAULT 0 COMMENT '所属商家ID',
  `sku_code` varchar(100) NOT NULL COMMENT '商家编码（唯一，用于ERP/WMS对接）',
  `barcode` varchar(50) DEFAULT NULL COMMENT '条码/EAN/UPC（仓库扫描用，NULL表示无条码）',
  `spec_summary` varchar(500) DEFAULT '' COMMENT '规格文本快照（如：红色 / 256G）',

  -- 价格
  `price` bigint NOT NULL COMMENT '销售价（分）',
  `market_price` bigint NOT NULL DEFAULT 0 COMMENT '划线价/市场价（分）',
  `cost_price` bigint NOT NULL DEFAULT 0 COMMENT '成本价（分，仅后台可见）',

  -- 物流
  `weight` decimal(10,2) NOT NULL DEFAULT 0.00 COMMENT '重量（克）',
  `volume` decimal(10,2) NOT NULL DEFAULT 0.00 COMMENT '体积（立方厘米）',
  `length` decimal(10,2) NOT NULL DEFAULT 0.00 COMMENT '长（厘米）',
  `width` decimal(10,2) NOT NULL DEFAULT 0.00 COMMENT '宽（厘米）',
  `height` decimal(10,2) NOT NULL DEFAULT 0.00 COMMENT '高（厘米）',

  -- 限购
  `min_purchase_qty` int NOT NULL DEFAULT 1 COMMENT '最少购买数量',
  `max_purchase_qty` int NOT NULL DEFAULT 0 COMMENT '最大购买数量（0=不限）',

  -- 媒体
  `image` varchar(512) DEFAULT '' COMMENT 'SKU专属图（如不同颜色展示不同图片）',

  -- 状态
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '1-正常 0-禁用（如某规格暂时缺货下架）',

  -- 审计字段
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
UNIQUE KEY `uk_merchant_sku_code` (`merchant_id`, `sku_code`) COMMENT '同一商家下SKU编码唯一',
  UNIQUE KEY `uk_barcode` (`barcode`) COMMENT '条码唯一约束',
  KEY `idx_merchant` (`merchant_id`),
  KEY `idx_product_id` (`product_id`) COMMENT '根据商品查SKU列表',
  KEY `idx_product_status` (`product_id`, `status`) COMMENT '查询有效SKU'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SKU规格表（具体可售单元）';


CREATE TABLE `sp_product_attributes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `product_id` bigint NOT NULL COMMENT '关联 products.id',
  `attribute_id` bigint NOT NULL COMMENT '关联 attributes.id',
  `value` varchar(500) NOT NULL COMMENT '属性值（如：A16）',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序权重（越小越靠前，用于控制前台展示顺序）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '软删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_product_attribute` (`product_id`, `attribute_id`),
  KEY `idx_attribute` (`attribute_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SPU扩展属性值表';


CREATE TABLE `sp_product_descriptions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `product_id` bigint NOT NULL COMMENT '关联 products.id',
  `description` longtext COMMENT '商品详情（富文本HTML）',
  `mobile_description` longtext COMMENT '移动端详情（可选，适配手机展示）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_product_id` (`product_id`) COMMENT '一个SPU只有一条详情记录'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品详情表（从主表拆出，减少主表体积）';


CREATE TABLE `sp_attribute_values` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `attribute_id` bigint NOT NULL COMMENT '关联属性ID',
  `value` varchar(200) NOT NULL COMMENT '属性值（如：256G、红色）',
  `numeric_value` decimal(18,4) DEFAULT NULL COMMENT '数值型值（用于区间筛选）',
  `color_hex` varchar(10) DEFAULT '' COMMENT '颜色色值（#FF0000）',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序权重',
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '1-启用 0-禁用',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_attr_value` (`attribute_id`, `value`),
  KEY `idx_attr_filter` (`attribute_id`, `status`, `numeric_value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='属性值字典表';


CREATE TABLE `sp_sku_specs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `sku_id` bigint NOT NULL COMMENT '关联SKU ID',
  `attribute_id` bigint NOT NULL COMMENT '关联属性ID',
  `attribute_value_id` bigint NOT NULL COMMENT '关联属性值ID',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '展示顺序',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sku_attr` (`sku_id`, `attribute_id`),
  KEY `idx_attr_value_sku` (`attribute_id`, `attribute_value_id`, `sku_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SKU规格值表（EAV模型）';
