-- ============================================================
-- p0_reconcile_audit.sql — MySQL 订单—支付—退款日对账脚本
-- 依据 sql/P0_幂等与对账口径.md
-- 用法: mysql -u root -p eshop_db < sql/audit/p0_reconcile_audit.sql
-- 说明: 每段输出 0 行 = 通过；输出行 = 对账异常（需人工定位）
-- ============================================================

-- 1) 已支付/退款中/已退款订单，成功支付合计 ≠ 应支付金额
SELECT o.id, o.order_no, o.pay_amount, o.payment_status,
       COALESCE(p.paid_sum, 0) AS paid_sum
FROM tx_orders o
LEFT JOIN (
    SELECT order_no, SUM(amount) AS paid_sum
    FROM tx_payments
    WHERE status IN ('paid','refunding','refunded')
    GROUP BY order_no
) p ON p.order_no = o.order_no
WHERE o.deleted_at IS NULL
  AND o.payment_status IN ('paid','refunding','refunded')
  AND COALESCE(p.paid_sum, 0) <> o.pay_amount;

-- 2) 超退：成功退款合计 > 成功支付合计
SELECT r.order_no, SUM(r.amount) AS refunded_sum
FROM tx_refunds r
WHERE r.status = 'success'
GROUP BY r.order_no
HAVING refunded_sum > (
    SELECT COALESCE(SUM(amount),0) FROM tx_payments
    WHERE order_no = r.order_no AND status IN ('paid','refunding','refunded')
);

-- 3) 状态矛盾：订单 payment_status=refunded 但成功退款合计 < 成功支付合计
SELECT o.id, o.order_no, o.pay_amount,
       COALESCE(p.paid_sum,0)  AS paid_sum,
       COALESCE(r.refunded_sum,0) AS refunded_sum
FROM tx_orders o
LEFT JOIN (SELECT order_no, SUM(amount) paid_sum FROM tx_payments
           WHERE status IN ('paid','refunding','refunded') GROUP BY order_no) p
       ON p.order_no = o.order_no
LEFT JOIN (SELECT order_no, SUM(amount) refunded_sum FROM tx_refunds
           WHERE status='success' GROUP BY order_no) r
       ON r.order_no = o.order_no
WHERE o.deleted_at IS NULL AND o.payment_status = 'refunded'
  AND COALESCE(r.refunded_sum,0) < COALESCE(p.paid_sum,0);

-- 4) 退款单已成功但父订单 payment_status 未联动到 refunding/refunded
SELECT DISTINCT o.id, o.order_no, o.payment_status
FROM tx_refunds r
JOIN tx_orders o ON o.order_no = r.order_no AND o.deleted_at IS NULL
WHERE r.status = 'success'
  AND o.payment_status NOT IN ('refunding','refunded');

-- 5) 订单明细行已退款合计 > 订单项小计
SELECT order_id, order_no, id, subtotal, refund_amount
FROM tx_order_items
WHERE refund_amount > subtotal AND deleted_at IS NULL;

-- 6) 子单实付合计 ≠ 父单实付（父单存在子单时）
SELECT o.id, o.order_no, o.pay_amount,
       SUM(s.pay_amount) AS sub_pay_sum
FROM tx_orders o
JOIN tx_sub_orders s ON s.parent_order_id = o.id AND s.deleted_at IS NULL
WHERE o.deleted_at IS NULL
GROUP BY o.id, o.order_no, o.pay_amount
HAVING sub_pay_sum <> o.pay_amount;
