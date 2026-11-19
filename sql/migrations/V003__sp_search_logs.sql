-- 搜索词日志表：C 端搜索埋点，供「热词 / 零结果词」统计
-- ============================================================
-- 目标基线：sql/sp_p0.sql（run.sh 基线，含本次变更）
--
-- 变更说明
--   新增 sp_search_logs：products / brands 列表接口的搜索词埋点。
--   写入由应用异步批量完成（有界队列 + 2s 刷盘），因此本表是**只追加**表，
--   没有 updated_at / deleted_at，也不参与任何业务流程的读写。
--
--   用途（应用侧 GET /api/v1/search_logs/stats）：
--     热词榜：高频搜索词 → 指导运营与选品
--     零结果榜：搜了但没结果的词 → 补同义词 / 补 IK 词典 / 补商品
--     零结果率：搜索质量的首要指标
--
--   索引与查询的对应关系：
--     idx_created_at           保留期清理（DELETE WHERE created_at < ?）+ 时间窗统计
--     idx_keyword              按词 GROUP BY（utf8mb4_unicode_ci 天然合并大小写，
--                              故不需要额外的规范化列）
--     idx_scene_created        按场景 + 时间窗统计
--
-- 破坏性评估：**非破坏性**——纯新增表，不触碰任何既有表。
--
-- 回滚方式（前向为主；紧急回滚由 DBA 审批后手工执行，并删除 schema_migrations 记录）
--   DROP TABLE IF EXISTS `sp_search_logs`;
--
-- 生产注意
--   本表只增不减，必须配置保留期（建议 90 天，与应用统计窗口上限一致），
--   否则会无限增长。执行方式见 sql/P1_大表生命周期.md：
--     DELETE FROM sp_search_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY) LIMIT 10000;
--   分批删除并间隔执行，避免长事务与主从延迟。
--
-- 分片键：无（分析型追加表，与 base_/sys_ 同类例外，见 docs/DB_CONVENTIONS.md §9.2）
-- ============================================================

CREATE TABLE IF NOT EXISTS `sp_search_logs` (
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
