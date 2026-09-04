-- ============================================================
-- p1_funds_append_only_audit.sql — PostgreSQL 资金表只可追加复核
-- 依据 sql/P1_资金结算链路.md
-- 用法: psql -U postgres -d eshop_db -f pgsql/audit/p1_funds_append_only_audit.sql
-- 说明: 输出 0 行 = 通过；输出行 = 待整改项
-- ============================================================

-- 1) 6 张资金表不应存在 deleted_at 列
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = current_schema()
  AND table_name IN ('tx_payments','tx_refunds','mch_merchant_balances',
                     'mch_merchant_withdrawals','mch_merchant_settlement_logs','mch_settlement_details')
  AND column_name = 'deleted_at'
ORDER BY table_name;

-- 2) 不应存在引用 deleted_at 的索引（含部分索引）
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = current_schema()
  AND tablename IN ('tx_payments','tx_refunds','mch_merchant_balances',
                    'mch_merchant_withdrawals','mch_merchant_settlement_logs','mch_settlement_details')
  AND (indexname ILIKE '%deleted%' OR indexdef ILIKE '%deleted_at%')
ORDER BY tablename, indexname;

-- 3) 其余核心表保留软删除（应全部命中）
SELECT table_name
FROM information_schema.columns
WHERE table_schema = current_schema()
  AND column_name = 'deleted_at'
  AND table_name IN ('tx_orders','tx_sub_orders','tx_order_items','tx_deliveries',
                     'tx_carts','tx_cart_items','mch_merchants','usr_users')
ORDER BY table_name;
