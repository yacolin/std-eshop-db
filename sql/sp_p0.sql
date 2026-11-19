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


-- ------------------------------------------------------------
-- 检索日志：C 端搜索词埋点，供「热词 / 零结果词」统计
--
-- 为什么放在 sp 域：埋点对象是商品与品牌的检索，属于商品域事件；
-- 为什么不建唯一键：同一用户可反复搜同一个词，天然不唯一；
-- 分片键：无。分析型追加表，与 base_/sys_ 同类例外（DB_CONVENTIONS §9.2），
--   按 created_at 保留期归档，不按 merchant/user 分片；
-- created_at 由应用在**入队时**打戳，不是落库时取 now()，
--   否则批量写入的延迟会被算进统计时间窗。
-- 保留期建议 90 天（统计接口窗口上限同为 90 天），见 sql/P1_大表生命周期.md。
-- ------------------------------------------------------------
CREATE TABLE `sp_search_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '日志ID',
  `keyword` varchar(100) NOT NULL COMMENT '搜索词（用户输入原文，已合并连续空白并截断到 100 字符）',
  `scene` varchar(20) NOT NULL DEFAULT '' COMMENT '检索场景：products-商品 brands-品牌',
  `result_count` int NOT NULL DEFAULT 0 COMMENT '本次返回的当前页条数（0=零结果；商品侧游标分页不做 COUNT，故为下界）',
  `user_id` bigint NOT NULL DEFAULT 0 COMMENT '登录用户ID，0=匿名（关联 usr_users.id）',
  `ip` varchar(64) DEFAULT '' COMMENT '来源 IP（IPv4/IPv6）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_created_at` (`created_at`) COMMENT '保留期清理 + 时间窗统计',
  KEY `idx_keyword` (`keyword`) COMMENT '按词分组统计（utf8mb4_unicode_ci 天然合并大小写）',
  KEY `idx_scene_created` (`scene`, `created_at`) COMMENT '按场景 + 时间窗统计'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='搜索词日志（只追加，用于热词与零结果分析）';
