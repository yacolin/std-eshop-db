-- ============================================================
-- p2_constraint_index_audit.sql — PostgreSQL 约束/索引审计（P2）
-- 依据 sql/P2_约束索引审计.md
-- 用法: psql -U postgres -d eshop_db -f pgsql/audit/p2_constraint_index_audit.sql
-- 说明: 输出 0 行 = 通过；输出行 = 待整改/人工复核
-- ============================================================

-- 1) 全库不存在 FOREIGN KEY（应 0 行）
SELECT tc.table_name, tc.constraint_name
FROM information_schema.table_constraints tc
WHERE tc.table_schema = current_schema()
  AND tc.constraint_type = 'FOREIGN KEY';

-- 2) 同表重复索引（非主键、列集合相同，应 0 行；部分索引带谓词不算重复）
WITH idx_cols AS (
    SELECT t.relname AS table_name,
           i.relname AS index_name,
           array_agg(a.attname ORDER BY k.ordinality) AS cols,
           x.indpred IS NOT NULL AS is_partial
    FROM pg_index x
    JOIN pg_class t ON t.oid = x.indrelid
    JOIN pg_class i ON i.oid = x.indexrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    CROSS JOIN LATERAL unnest(x.indkey) WITH ORDINALITY AS k(attnum, ordinality)
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = k.attnum
    WHERE n.nspname = current_schema()
      AND NOT x.indisprimary
    GROUP BY t.relname, i.relname, x.indpred
)
SELECT a.table_name, a.index_name AS idx1, b.index_name AS idx2, a.cols::text
FROM idx_cols a
JOIN idx_cols b
  ON a.table_name = b.table_name AND a.index_name < b.index_name
 AND a.cols = b.cols
 AND NOT a.is_partial AND NOT b.is_partial
ORDER BY a.table_name;

-- 3) 唯一约束/索引列仍以空串为默认值（应 0 行；_uq 生成列除外）
SELECT DISTINCT c.table_name, c.column_name
FROM information_schema.columns c
JOIN pg_indexes s
  ON s.schemaname = c.table_schema
 AND s.tablename  = c.table_name
 AND s.indexdef ILIKE '%unique%'
WHERE c.table_schema = current_schema()
  AND c.column_default = ''''''::text
  AND c.column_name NOT LIKE '%\_uq'
ORDER BY c.table_name, c.column_name;

-- 4) 金额列类型漂移复查（bigint 或 money DOMAIN）
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = current_schema()
  AND table_name || '.' || column_name IN (
    'tx_orders.total_amount','tx_orders.pay_amount','tx_sub_orders.pay_amount',
    'tx_order_items.subtotal','tx_payments.amount','tx_refunds.amount',
    'sp_skus.price','mch_merchant_balances.available_balance')
  AND data_type NOT IN ('bigint','money_amount','positive_money');

-- 5) 资金表仍存在 deleted_at（应 0 行，P1 规则）
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = current_schema()
  AND table_name IN ('tx_payments','tx_refunds','mch_merchant_balances',
                     'mch_merchant_withdrawals','mch_merchant_settlement_logs','mch_settlement_details')
  AND column_name = 'deleted_at';
