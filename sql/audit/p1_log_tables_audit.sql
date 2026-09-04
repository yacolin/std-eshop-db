-- ============================================================
-- p1_log_tables_audit.sql — MySQL 大表生命周期复核
-- 依据 sql/P1_大表生命周期.md
-- 用法: mysql -u root -p eshop_db < sql/audit/p1_log_tables_audit.sql
-- 说明: 列出日志表行龄分布，供归档/保留策略决策
-- ============================================================

-- 1) 各日志表总行数与最近写入时间
SELECT TABLE_NAME, TABLE_ROWS, UPDATE_TIME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('tx_payment_logs','tx_order_logs','sys_operation_logs',
                     'sp_inventory_logs','tx_delivery_traces','mkt_promotion_usage_logs')
ORDER BY TABLE_NAME;

-- 2) 各日志表 created_at 年龄分布（按月，供保留期决策）
--    需在目标表上执行（示例 tx_payment_logs）：
-- SELECT DATE_FORMAT(created_at, '%Y-%m') AS ym, COUNT(*) AS cnt
-- FROM tx_payment_logs
-- GROUP BY DATE_FORMAT(created_at, '%Y-%m')
-- ORDER BY ym;

-- 3) 在线表是否已存在归档表命名（_YYYYMM），避免重复归档
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND (TABLE_NAME LIKE 'tx_payment_logs\_%'
    OR TABLE_NAME LIKE 'tx_order_logs\_%'
    OR TABLE_NAME LIKE 'sys_operation_logs\_%'
    OR TABLE_NAME LIKE 'sp_inventory_logs\_%'
    OR TABLE_NAME LIKE 'tx_delivery_traces\_%'
    OR TABLE_NAME LIKE 'mkt_promotion_usage_logs\_%')
ORDER BY TABLE_NAME;
