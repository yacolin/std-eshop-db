-- ============================================================
-- PostgreSQL 电商数据库完整建表脚本
-- 按依赖层级分批执行：初始化 → Types → P0 → P5
--
-- 用法:
--   bash pgsql/run.sh                                  (推荐)
--   psql -U postgres -d eshop_db -f pgsql/run.sql      (手动)
-- ============================================================

-- ========== 初始化: 扩展 + 共享函数 ==========
\i pgsql/00_init.sql

-- ========== 删除旧表（P5 → P0）==========
\i pgsql/00_drop_tables.sql

-- ========== 类型定义（必须先于建表）==========
\i pgsql/01_enums.sql
\i pgsql/01_domains.sql

-- ========== P0: 独立基础表 ==========
\i pgsql/base_p0.sql
\i pgsql/usr_p0.sql
\i pgsql/sys_p0.sql
\i pgsql/sp_p0.sql
\i pgsql/mch_p0.sql

-- ========== P1: 核心业务表 ==========
\i pgsql/usr_p1.sql
\i pgsql/mch_p1.sql
\i pgsql/sp_p1.sql
\i pgsql/tx_p0.sql
\i pgsql/mkt_p0.sql
\i pgsql/rev_p0.sql

-- ========== P2: 关联业务表 ==========
\i pgsql/sp_p2.sql
\i pgsql/tx_p1.sql
\i pgsql/tx_p2.sql
\i pgsql/mkt_p1.sql
\i pgsql/rev_p1.sql

-- ========== P3: 库存相关表 ==========
\i pgsql/sp_p3.sql

-- ========== P4: 仓配/售后/结算 ==========
\i pgsql/sp_p4.sql
\i pgsql/mch_p2.sql
\i pgsql/tx_p3.sql
\i pgsql/tx_p4.sql

-- ========== P5: 版本/审计表 ==========
\i pgsql/sp_p5.sql

-- ========== 创建分区子表 ==========
\i pgsql/03_partitions.sql

-- ========== 物化视图 ==========
\i pgsql/04_materialized_views.sql

-- ========== 高级特性（可选）==========
-- 以下为高级 PostgreSQL 特性，可根据实际需求启用
-- \i pgsql/02_notify.sql
-- \i pgsql/02_procedures.sql
