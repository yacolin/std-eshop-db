USE eshop_db;

-- ============================================================
-- sp_p1.sql — 商品域核心业务表（依赖 P0）
-- ============================================================

CREATE TABLE `sp_attributes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL COMMENT '属性名称（如：处理器、屏幕尺寸）',
  `category_id` bigint NOT NULL COMMENT '所属类目ID（该属性只出现在这个类目下）',
  `input_type` tinyint NOT NULL DEFAULT 1 COMMENT '1-文本输入 2-单选 3-多选 4-数字',
  `values` json DEFAULT NULL COMMENT '可选值列表（如["A15","A16"]，仅单选/多选时使用）',
  `unit` varchar(20) DEFAULT '' COMMENT '单位（如：英寸、GB）',
  `required` tinyint NOT NULL DEFAULT 0 COMMENT '1-必填（该属性在该类目下创建商品时必须填写）',
  `searchable` tinyint NOT NULL DEFAULT 0 COMMENT '1-作为前台筛选条件（列表页筛选项来源）',
  `is_sku_spec` tinyint NOT NULL DEFAULT 0 COMMENT '1-是SKU规格（如颜色、内存） 0-仅SPU属性（如上市时间）',
  `sort_order` int NOT NULL DEFAULT 0,
  `status` tinyint NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_category` (`category_id`),
  KEY `idx_is_sku_spec` (`is_sku_spec`),
  KEY `idx_searchable` (`category_id`, `searchable`, `status`) COMMENT '前台筛选条件查询',
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='属性字典表';


CREATE TABLE `sp_products` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'SPU ID',
  `merchant_id` bigint NOT NULL DEFAULT 0 COMMENT '所属商家ID',

  -- 基础信息
  `name` varchar(200) NOT NULL COMMENT '商品名称（用于搜索和展示）',
  `subtitle` varchar(500) DEFAULT '' COMMENT '商品副标题（卖点文案，如"2026新款"）',
  `category_id` bigint NOT NULL DEFAULT 0 COMMENT '前台主类目ID（叶子节点）',
  `brand_id` bigint NOT NULL DEFAULT 0 COMMENT '品牌ID',
  `unit` varchar(10) DEFAULT '件' COMMENT '单位（件/箱/台/套）',

  -- 媒体资源
  `main_image` varchar(512) NOT NULL DEFAULT '' COMMENT '主图URL（CDN地址）',
  `images` json DEFAULT NULL COMMENT '附图JSON数组（最多10张）',
  `video_url` varchar(512) DEFAULT '' COMMENT '主图视频URL',

  -- 价格 & 库存聚合（触发器维护，只读）
  `min_price` bigint NOT NULL DEFAULT 0 COMMENT 'SKU最低价（分）',
  `max_price` bigint NOT NULL DEFAULT 0 COMMENT 'SKU最高价（分）',
  `total_stock` int NOT NULL DEFAULT 0 COMMENT '可售库存总和（SUM(quantity - reserved)）',

  -- 运营数据（定时任务聚合）
  `sales_count` int NOT NULL DEFAULT 0 COMMENT '总销量（从订单明细聚合，每日更新）',
  `rating_average` decimal(3,2) NOT NULL DEFAULT 0.00 COMMENT '平均评分（1-5）',
  `rating_count` int NOT NULL DEFAULT 0 COMMENT '评价总数',

  -- 状态 & 权重
  `status` tinyint NOT NULL DEFAULT 0 COMMENT '0-草稿 1-待审 2-已上架 3-已下架 4-违规封禁',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序权重（越大越靠前，运营手动调整）',

  -- 详情标志（详情内容独立存储）
  `has_description` tinyint NOT NULL DEFAULT 0 COMMENT '1-有图文详情（存于 sp_product_descriptions 表）',

  -- 审计字段
  `created_by` varchar(50) DEFAULT '' COMMENT '创建人（运营工号）',
  `updated_by` varchar(50) DEFAULT '' COMMENT '最后更新人',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '软删除时间（NULL表示未删除）',

  PRIMARY KEY (`id`),
  KEY `idx_merchant` (`merchant_id`),
  KEY `idx_category_status_sort` (`category_id`, `status`, `sort_order` DESC, `id` DESC) COMMENT '前台列表页主查询',
  KEY `idx_brand_status` (`brand_id`, `status`) COMMENT '品牌筛选',
  KEY `idx_status_sales` (`status`, `sales_count` DESC) COMMENT '销量排序',
  KEY `idx_status_rating` (`status`, `rating_average` DESC) COMMENT '评分排序',
  KEY `idx_created_at` (`created_at`) COMMENT '后台按创建时间筛选',
  KEY `idx_deleted_at` (`deleted_at`) COMMENT '软删除查询',
  FULLTEXT KEY `ft_search` (`name`, `subtitle`) COMMENT '商品名称+副标题全文检索'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品SPU主表（前台展示聚合层）';
