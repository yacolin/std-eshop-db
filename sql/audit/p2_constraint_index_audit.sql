-- ============================================================
-- p2_constraint_index_audit.sql — MySQL 约束/索引审计（P2）
-- 依据 sql/P2_约束索引审计.md
-- 用法: mysql -u root -p eshop_db < sql/audit/p2_constraint_index_audit.sql
-- 说明: 输出 0 行 = 通过；输出行 = 待整改/人工复核
-- ============================================================

-- 1) 全库不存在 FOREIGN KEY（应 0 行）
SELECT TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = DATABASE()
  AND CONSTRAINT_TYPE = 'FOREIGN KEY';

-- 2) 同表重复索引（非主键、列序完全相同的不同索引，应 0 行）
SELECT idx1.TABLE_NAME, idx1.INDEX_NAME AS idx_a, idx2.INDEX_NAME AS idx_b,
       idx1.cols
FROM (
    SELECT TABLE_NAME, INDEX_NAME,
           GROUP_CONCAT(CONCAT_WS(':', COLUMN_NAME, SUB_PART) ORDER BY SEQ_IN_INDEX) AS cols
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND INDEX_NAME <> 'PRIMARY'
    GROUP BY TABLE_NAME, INDEX_NAME
) idx1
JOIN (
    SELECT TABLE_NAME, INDEX_NAME,
           GROUP_CONCAT(CONCAT_WS(':', COLUMN_NAME, SUB_PART) ORDER BY SEQ_IN_INDEX) AS cols
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND INDEX_NAME <> 'PRIMARY'
    GROUP BY TABLE_NAME, INDEX_NAME
) idx2
  ON idx1.TABLE_NAME = idx2.TABLE_NAME
 AND idx1.INDEX_NAME < idx2.INDEX_NAME
 AND idx1.cols = idx2.cols
ORDER BY idx1.TABLE_NAME, idx1.INDEX_NAME;

-- 3) 唯一键列中仍以空串为默认值（应为 0 行；已用生成列归一的除外）
SELECT DISTINCT s.TABLE_NAME, s.COLUMN_NAME
FROM information_schema.STATISTICS s
WHERE s.TABLE_SCHEMA = DATABASE()
  AND s.NON_UNIQUE = 0
  AND s.INDEX_NAME <> 'PRIMARY'
  AND s.COLUMN_NAME NOT LIKE '%_uq'
  AND s.COLUMN_NAME IN (
      SELECT c.COLUMN_NAME FROM information_schema.COLUMNS c
      WHERE c.TABLE_SCHEMA = s.TABLE_SCHEMA
        AND c.TABLE_NAME   = s.TABLE_NAME
        AND c.COLUMN_DEFAULT = ''
  )
ORDER BY s.TABLE_NAME, s.COLUMN_NAME;

-- 4) 金额列类型漂移复查（P0 规则；权威清单见 P0_金额审计清单.md）
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND CONCAT(TABLE_NAME, '.', COLUMN_NAME) IN (
    'tx_orders.total_amount','tx_orders.pay_amount','tx_sub_orders.pay_amount',
    'tx_order_items.subtotal','tx_payments.amount','tx_refunds.amount',
    'sp_skus.price','mch_merchant_balances.available_balance')
  AND DATA_TYPE <> 'bigint';

-- 5) 资金表仍存在 deleted_at（应 0 行，P1 规则）
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('tx_payments','tx_refunds','mch_merchant_balances',
                     'mch_merchant_withdrawals','mch_merchant_settlement_logs','mch_settlement_details')
  AND COLUMN_NAME = 'deleted_at';
