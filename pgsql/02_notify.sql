-- ============================================================
-- 02_notify.sql — LISTEN/NOTIFY 实时事件通知
-- 在表级触发器基础上增加异步事件推送
-- PG 连接池（PgBouncer）需配置 listen 模式
-- ============================================================

-- ==================== 订单状态变更通知 ====================
CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        PERFORM pg_notify(
            'order_status_changed',
            json_build_object(
                'order_id', NEW.id,
                'order_no', NEW.order_no,
                'user_id', NEW.user_id,
                'old_status', OLD.status,
                'new_status', NEW.status,
                'changed_at', CURRENT_TIMESTAMP
            )::text
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_status_notify ON tx_orders;
CREATE TRIGGER trg_order_status_notify
    AFTER UPDATE ON tx_orders
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION notify_order_status_change();

-- ==================== 库存预警通知 ====================
CREATE OR REPLACE FUNCTION notify_low_stock()
RETURNS TRIGGER AS $$
BEGIN
    -- 仅当库存从充足变为低于阈值时通知
    IF NEW.available >= 0 AND NEW.available <= NEW.threshold
       AND (OLD.available > NEW.threshold OR OLD.available IS NULL) THEN
        PERFORM pg_notify(
            'low_stock_alert',
            json_build_object(
                'sku_id', NEW.sku_id,
                'warehouse_id', NEW.warehouse_id,
                'merchant_id', NEW.merchant_id,
                'available', NEW.available,
                'threshold', NEW.threshold,
                'alerted_at', CURRENT_TIMESTAMP
            )::text
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inventory_low_stock_notify ON sp_inventories;
CREATE TRIGGER trg_inventory_low_stock_notify
    AFTER UPDATE ON sp_inventories
    FOR EACH ROW
    WHEN (NEW.available IS DISTINCT FROM OLD.available)
    EXECUTE FUNCTION notify_low_stock();

-- ==================== 支付成功通知 ====================
CREATE OR REPLACE FUNCTION notify_payment_success()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'paid'::payment_status
       AND (OLD.status IS DISTINCT FROM NEW.status) THEN
        PERFORM pg_notify(
            'payment_success',
            json_build_object(
                'payment_no', NEW.payment_no,
                'order_no', NEW.order_no,
                'amount', NEW.amount,
                'paid_at', NEW.paid_at,
                'transaction_id', NEW.transaction_id
            )::text
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_payment_success_notify ON tx_payments;
CREATE TRIGGER trg_payment_success_notify
    AFTER UPDATE ON tx_payments
    FOR EACH ROW
    WHEN (NEW.status = 'paid'::payment_status)
    EXECUTE FUNCTION notify_payment_success();
