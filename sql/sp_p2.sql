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


CREATE TABLE sp_category_attributes (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_id BIGINT NOT NULL COMMENT '类目ID',
  attribute_id BIGINT NOT NULL COMMENT '属性ID',
  required TINYINT DEFAULT 0 COMMENT '该类目下是否必填（仅提示，非强校验）',
  is_default_filter TINYINT DEFAULT 0 COMMENT '是否作为前台默认筛选项',
  sort_order INT DEFAULT 0,
  created_at DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_cat_attr (category_id, attribute_id),
  KEY idx_category (category_id)
) COMMENT='类目-属性弱关联表（推荐模板）';


CREATE TABLE `sp_product_attributes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `product_id` bigint NOT NULL COMMENT '关联 products.id',
  `attribute_id` bigint NOT NULL COMMENT '关联 attributes.id',
  `attribute_value_id` bigint DEFAULT NULL COMMENT '引用属性值字典ID（可选，关联 attribute_values.id）',
  `value` varchar(500) NOT NULL COMMENT '属性值（如：A16）。有字典值时冗余存储便于展示，无字典值时存自由文本',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序权重（越小越靠前，用于控制前台展示顺序）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '软删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_product_attribute` (`product_id`, `attribute_id`, `attribute_value_id`),
  KEY `idx_attribute` (`attribute_id`),
  KEY `idx_attribute_value` (`attribute_value_id`) COMMENT '字典值筛选'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SPU扩展属性值表';

-- 写入规则：
--   attribute_value_id IS NOT NULL → 有字典值，一行一个字典值
--   attribute_value_id IS NULL     → 无字典值，value 存自由文本
--   value 字段始终冗余存储展示文本，避免频繁 JOIN


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
  `alias` json DEFAULT NULL COMMENT '别名列表，如["深空灰","黑灰"]，用于搜索纠错、模糊匹配',
  `search_weight` int NOT NULL DEFAULT 0 COMMENT '搜索权重（值越大匹配优先级越高）',
  `numeric_value` decimal(18,4) DEFAULT NULL COMMENT '数值型值（用于区间筛选）',
  `color_hex` varchar(10) DEFAULT '' COMMENT '颜色色值（#FF0000）',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序权重',
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '1-启用 0-禁用',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_attr_value` (`attribute_id`, `value`),
  KEY `idx_attr_filter` (`attribute_id`, `status`, `numeric_value`),
  KEY `idx_search_weight` (`attribute_id`, `search_weight`) COMMENT '搜索权重排序'
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
