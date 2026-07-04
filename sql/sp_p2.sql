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

  -- 规格信息
  `spec` json NOT NULL COMMENT '规格JSON（如{"颜色":"红色","内存":"256G"}）',
  `spec_signature` varchar(32) NOT NULL DEFAULT '' COMMENT '规格MD5签名（用于快速匹配，由应用层计算）',

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
  UNIQUE KEY `uk_product_spec` (`product_id`, `spec_signature`) COMMENT '同一SPU下规格组合唯一',
  UNIQUE KEY `uk_barcode` (`barcode`) COMMENT '条码唯一约束',
  CONSTRAINT `fk_sp_skus_product` FOREIGN KEY (`product_id`) REFERENCES `sp_products` (`id`),
  KEY `idx_merchant` (`merchant_id`),
  KEY `idx_product_id` (`product_id`) COMMENT '根据商品查SKU列表',
  KEY `idx_product_status` (`product_id`, `status`) COMMENT '查询有效SKU',
  KEY `idx_deleted_at` (`deleted_at`)
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
  KEY `idx_attribute` (`attribute_id`),
  KEY `idx_deleted_at` (`deleted_at`)
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
