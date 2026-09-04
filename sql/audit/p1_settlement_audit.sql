-- ============================================================
-- p1_settlement_audit.sql — MySQL 结算聚合一致性复核
-- 依据 sql/P1_资金结算链路.md §1.2
-- 用法: mysql -u root -p eshop_db < sql/audit/p1_settlement_audit.sql
-- 说明: 输出 0 行 = 通过；输出行 = 待整改项
-- ============================================================

-- 1) 结算单金额 = Σ 明细金额（同 settlement_log_id）
SELECT sl.id AS settlement_log_id, sl.settlement_no,
       sl.settlement_amount,
       COALESCE(SUM(d.settlement_amount), 0) AS detail_sum,
       sl.total_amount,
       COALESCE(SUM(d.order_amount), 0)     AS detail_order_sum,
       sl.commission_amount,
       COALESCE(SUM(d.commission_amount), 0) AS detail_commission_sum
FROM mch_merchant_settlement_logs sl
LEFT JOIN mch_settlement_details d ON d.settlement_log_id = sl.id
GROUP BY sl.id, sl.settlement_no, sl.settlement_amount, sl.total_amount, sl.commission_amount
HAVING COALESCE(SUM(d.settlement_amount), 0) <> sl.settlement_amount
    OR COALESCE(SUM(d.commission_amount), 0) <> sl.commission_amount;

-- 2) 佣金率合法范围（0–1000 千分比）：佣金 > 订单实付则异常（费率越界或错账）
SELECT d.id, d.order_id, d.order_amount, d.commission_amount
FROM mch_settlement_details d
WHERE d.commission_amount < 0
   OR d.commission_amount > d.order_amount;

-- 3) 已结算单存在明细缺失（结算单有金额但无任何明细行）
SELECT sl.id, sl.settlement_no, sl.settlement_amount
FROM mch_merchant_settlement_logs sl
WHERE sl.settlement_amount > 0
  AND NOT EXISTS (SELECT 1 FROM mch_settlement_details d
                  WHERE d.settlement_log_id = sl.id);

-- 4) 退款冲减不为负
SELECT id, order_id, refund_amount
FROM mch_settlement_details
WHERE refund_amount < 0;
