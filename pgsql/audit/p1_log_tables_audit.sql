-- ============================================================
-- p1_log_tables_audit.sql — PostgreSQL 大表生命周期复核
-- 依据 sql/P1_大表生命周期.md
-- 用法: psql -U postgres -d eshop_db -f pgsql/audit/p1_log_tables_audit.sql
-- 说明: 列出日志表是否已分区及行龄，供保留/归档策略参考
-- ============================================================

-- 1) 6 张日志表的分区属性（relkind: p=分区表, r=普通表）
SELECT c.relname AS table_name,
       CASE c.relkind WHEN 'p' THEN 'partitioned' WHEN 'r' THEN 'plain' ELSE c.relkind::text END AS kind,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = current_schema()
  AND c.relkind IN ('r','p')
  AND c.relname IN ('tx_payment_logs','tx_order_logs','sys_operation_logs',
                    'sp_inventory_logs','tx_delivery_traces','mkt_promotion_usage_logs')
ORDER BY c.relname;

-- 2) 各分区子表清单（确认按月分区已建立）
SELECT parent.relname AS parent_table,
       child.relname AS partition_name
FROM pg_inherits inh
JOIN pg_class parent ON parent.oid = inh.inhparent
JOIN pg_class child  ON child.oid  = inh.inhrelid
JOIN pg_namespace n  ON n.oid = parent.relnamespace
WHERE n.nspname = current_schema()
  AND parent.relname IN ('tx_payment_logs','tx_order_logs','sys_operation_logs',
                         'sp_inventory_logs','tx_delivery_traces','mkt_promotion_usage_logs')
ORDER BY parent.relname, child.relname;
