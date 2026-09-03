-- ============================================================
-- p0_money_audit.sql — PostgreSQL 金额字段审计脚本
-- 依据 sql/P0_金额审计清单.md
-- 用法: psql -U postgres -d eshop_db -f pgsql/audit/p0_money_audit.sql
-- 说明: 每段输出 0 行 = 通过；输出行 = 待整改项
-- ============================================================

-- 1) 金额列类型漂移 / 可空：金额应为 bigint(分) NOT NULL（域 money_amount/positive_money 亦合规）
SELECT c.table_name, c.column_name, c.data_type, c.udt_name, c.is_nullable
FROM information_schema.columns c
WHERE c.table_schema = current_schema()
  AND c.table_name || '.' || c.column_name IN (
    'tx_orders.total_amount','tx_orders.discount_amount','tx_orders.shipping_fee','tx_orders.pay_amount',
    'tx_sub_orders.total_amount','tx_sub_orders.discount_amount','tx_sub_orders.shipping_fee','tx_sub_orders.pay_amount',
    'tx_order_items.price','tx_order_items.subtotal','tx_order_items.refund_amount',
    'tx_cart_items.price','tx_payments.amount','tx_refunds.amount','tx_after_sales.amount','tx_deliveries.shipping_fee',
    'sp_skus.price','sp_skus.market_price','sp_skus.cost_price',
    'mch_merchants.total_sales','mch_merchant_balances.available_balance','mch_merchant_balances.freeze_balance',
    'mch_merchant_withdrawals.amount',
    'mch_merchant_settlement_logs.total_amount','mch_merchant_settlement_logs.commission_amount','mch_merchant_settlement_logs.settlement_amount',
    'mch_settlement_details.order_amount','mch_settlement_details.commission_amount','mch_settlement_details.settlement_amount','mch_settlement_details.refund_amount',
    'mkt_promotion_usage_logs.discount_amount'
  )
  AND (c.data_type NOT IN ('bigint','money_amount','positive_money') OR c.is_nullable = 'YES');

-- 2) 金额列 CHECK 覆盖复核：清单金额列所在表若无引用该列且含 >=/> 的约束/域则列出
WITH money_cols AS (
    SELECT 'tx_orders' t, 'total_amount' c UNION ALL SELECT 'tx_orders','discount_amount'
    UNION ALL SELECT 'tx_orders','shipping_fee' UNION ALL SELECT 'tx_orders','pay_amount'
    UNION ALL SELECT 'tx_sub_orders','total_amount' UNION ALL SELECT 'tx_sub_orders','discount_amount'
    UNION ALL SELECT 'tx_sub_orders','shipping_fee' UNION ALL SELECT 'tx_sub_orders','pay_amount'
    UNION ALL SELECT 'tx_order_items','price' UNION ALL SELECT 'tx_order_items','subtotal'
    UNION ALL SELECT 'tx_order_items','refund_amount' UNION ALL SELECT 'tx_cart_items','price'
    UNION ALL SELECT 'tx_payments','amount' UNION ALL SELECT 'tx_refunds','amount'
    UNION ALL SELECT 'tx_after_sales','amount' UNION ALL SELECT 'tx_deliveries','shipping_fee'
    UNION ALL SELECT 'sp_skus','price' UNION ALL SELECT 'sp_skus','market_price' UNION ALL SELECT 'sp_skus','cost_price'
    UNION ALL SELECT 'mch_merchants','total_sales'
    UNION ALL SELECT 'mch_merchant_balances','available_balance' UNION ALL SELECT 'mch_merchant_balances','freeze_balance'
    UNION ALL SELECT 'mch_merchant_withdrawals','amount'
    UNION ALL SELECT 'mch_merchant_settlement_logs','total_amount'
    UNION ALL SELECT 'mch_merchant_settlement_logs','commission_amount'
    UNION ALL SELECT 'mch_merchant_settlement_logs','settlement_amount'
    UNION ALL SELECT 'mch_settlement_details','order_amount' UNION ALL SELECT 'mch_settlement_details','commission_amount'
    UNION ALL SELECT 'mch_settlement_details','settlement_amount' UNION ALL SELECT 'mch_settlement_details','refund_amount'
    UNION ALL SELECT 'mkt_promotion_usage_logs','discount_amount'
),
table_checks AS (
    SELECT c.conrelid::regclass::text AS table_name,
           pg_get_constraintdef(c.oid) AS def
    FROM pg_constraint c
    WHERE c.contype = 'c' AND c.connamespace = current_schema()::regnamespace
)
SELECT mc.t, mc.c
FROM money_cols mc
LEFT JOIN table_checks tc
       ON tc.table_name = mc.t
      AND tc.def ~ (mc.c || '.*(>=|>|between)')
WHERE tc.table_name IS NULL
ORDER BY mc.t, mc.c;

-- 3) 幂等键必须 NOT NULL 且唯一；渠道交易号允许 NULL（生成后回填）但必须唯一
-- 3a) 幂等键可空（应为 0 行）
SELECT table_name, column_name, is_nullable
FROM information_schema.columns
WHERE table_schema = current_schema()
  AND ((table_name = 'tx_payments' AND column_name = 'idempotency_key')
    OR (table_name = 'tx_refunds'   AND column_name = 'idempotency_key'))
  AND is_nullable = 'YES';

-- 3b) 幂等键 + 渠道号唯一索引（应各返回 1 行）
SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = current_schema()
  AND tablename IN ('tx_payments','tx_refunds')
  AND indexdef ILIKE '%unique%'
  AND (indexdef ILIKE '%idempotency_key%'
    OR indexdef ILIKE '%transaction_id%'
    OR indexdef ILIKE '%channel_refund_id%')
ORDER BY tablename, indexname;
