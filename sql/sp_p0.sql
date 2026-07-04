USE eshop_db;

-- ============================================================
-- sp_p0.sql — 商品域独立基础表
-- ============================================================

CREATE TABLE `sp_categories` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL COMMENT '类目名称（如：手机）',
  `parent_id` bigint NOT NULL DEFAULT 0 COMMENT '父级ID（0表示根节点）',
  `level` tinyint NOT NULL DEFAULT 1 COMMENT '层级（1-3级）',
  `path` varchar(500) NOT NULL DEFAULT '' COMMENT '路径（如：1/23/45/）',
  `icon_url` varchar(512) DEFAULT '' COMMENT '类目图标',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序',
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '1-启用 0-禁用',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_parent_id` (`parent_id`),
  KEY `idx_path` (`path`(191)),
  KEY `idx_level_status` (`level`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='类目表（树状结构）';


CREATE TABLE `sp_brands` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL COMMENT '品牌名称（如：苹果）',
  `english_name` varchar(100) DEFAULT '' COMMENT '英文名',
  `logo_url` varchar(512) DEFAULT '' COMMENT '品牌Logo（CDN）',
  `first_letter` char(1) DEFAULT '' COMMENT '首字母（A-Z，用于前台索引筛选）',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序权重',
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '1-启用 0-禁用',
  `description` text COMMENT '品牌故事',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_name` (`name`),
  KEY `idx_first_letter` (`first_letter`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='品牌表';
