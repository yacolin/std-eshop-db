-- ============================================================
-- p1_funds_append_only_audit.sql — MySQL 资金表只可追加复核
-- 依据 sql/P1_资金结算链路.md
-- 用法: mysql -u root -p eshop_db < sql/audit/p1_funds_append_only_audit.sql
-- 说明: 输出 0 行 = 通过；输出行 = 待整改项
-- ============================================================

-- 1) 6 张资金表不应存在 deleted_at 列（资金表只可追加）
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('tx_payments','tx_refunds','mch_merchant_balances',
                     'mch_merchant_withdrawals','mch_merchant_settlement_logs','mch_settlement_details')
  AND COLUMN_NAME = 'deleted_at'
ORDER BY TABLE_NAME;

-- 2) 上述表不应存在 deleted_at 索引
SELECT TABLE_NAME, INDEX_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('tx_payments','tx_refunds','mch_merchant_balances',
                     'mch_merchant_withdrawals','mch_merchant_settlement_logs','mch_settlement_details')
  AND INDEX_NAME LIKE '%deleted%'
GROUP BY TABLE_NAME, INDEX_NAME;

-- 3) 其余核心表保留软删除（应全部命中：tx_orders/tx_sub_orders/tx_order_items 等）
SELECT TABLE_NAME, COUNT(*) AS deleted_cols
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME = 'deleted_at'
  AND TABLE_NAME IN ('tx_orders','tx_sub_orders','tx_order_items','tx_deliveries',
                     'tx_carts','tx_cart_items','mch_merchants','usr_users')
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;
