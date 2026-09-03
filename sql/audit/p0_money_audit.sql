-- ============================================================
-- p0_money_audit.sql — MySQL 金额字段审计脚本
-- 依据 sql/P0_金额审计清单.md
-- 用法: mysql -u root -p eshop_db < sql/audit/p0_money_audit.sql
-- 说明: 每段输出 0 行 = 通过；输出行 = 待整改项
-- ============================================================

-- 0) 金额字段清单（权威清单见 P0_金额审计清单.md §1；此处按名单核验）
--    名单之外的金额列请先加入清单再核验。

-- 1) 金额列类型漂移：应为 bigint（金额一律分存储）
SELECT c.TABLE_NAME, c.COLUMN_NAME, c.DATA_TYPE, c.IS_NULLABLE
FROM information_schema.COLUMNS c
WHERE c.TABLE_SCHEMA = DATABASE()
  AND CONCAT(c.TABLE_NAME, '.', c.COLUMN_NAME) IN (
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
  AND (c.DATA_TYPE <> 'bigint' OR c.IS_NULLABLE = 'YES');

-- 2) 金额列非负/正数 CHECK 覆盖复核：
--    对每个清单金额列，若所在表没有任何引用该列且含 '>=' / '>' / 'BETWEEN' 的 CHECK，则列出。
SELECT cl.TABLE_NAME, cl.COLUMN_NAME
FROM information_schema.COLUMNS cl
LEFT JOIN (
    SELECT tc.TABLE_NAME, cc.CHECK_CLAUSE
    FROM information_schema.TABLE_CONSTRAINTS tc
    JOIN information_schema.CHECK_CONSTRAINTS cc
      ON cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
     AND cc.CONSTRAINT_NAME   = tc.CONSTRAINT_NAME
    WHERE tc.TABLE_SCHEMA = DATABASE()
      AND tc.CONSTRAINT_TYPE = 'CHECK'
) chk ON chk.TABLE_NAME = cl.TABLE_NAME
     AND chk.CHECK_CLAUSE LIKE CONCAT('%`', cl.COLUMN_NAME, '`%')
     AND chk.CHECK_CLAUSE REGEXP '>= 0|> 0|BETWEEN'
WHERE cl.TABLE_SCHEMA = DATABASE()
  AND CONCAT(cl.TABLE_NAME, '.', cl.COLUMN_NAME) IN (
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
  AND chk.TABLE_NAME IS NULL
ORDER BY cl.TABLE_NAME, cl.COLUMN_NAME;

-- 3) 幂等键必须 NOT NULL 且唯一；渠道交易号允许 NULL（生成后回填）但必须唯一
-- 3a) 幂等键可空（应为 0 行）
SELECT TABLE_NAME, COLUMN_NAME, IS_NULLABLE, COLUMN_TYPE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND ((TABLE_NAME = 'tx_payments' AND COLUMN_NAME = 'idempotency_key')
    OR (TABLE_NAME = 'tx_refunds'   AND COLUMN_NAME = 'idempotency_key'))
  AND IS_NULLABLE = 'YES';

-- 3b) 幂等键 + 渠道号唯一索引（应各返回 1 行）
SELECT TABLE_NAME, INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) cols
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND NON_UNIQUE = 0
  AND TABLE_NAME IN ('tx_payments','tx_refunds')
  AND INDEX_NAME IN ('uk_idempotency_key','uk_transaction_id','uk_channel_refund_id')
GROUP BY TABLE_NAME, INDEX_NAME
ORDER BY TABLE_NAME, INDEX_NAME;
