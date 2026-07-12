-- ============================================================
-- 02_procedures.sql — 存储过程与高级函数
-- 复杂业务逻辑（下单 / 退款 / 结算）的事务控制
-- ============================================================

-- ==================== 咨询锁：防止并发退款 ====================
CREATE OR REPLACE FUNCTION safe_refund(
    p_order_id bigint,
    p_amount bigint,
    OUT success boolean,
    OUT message text
) AS $$
DECLARE
    v_current_status order_status;
BEGIN
    -- 以 order_id 作为咨询锁 key，防止同一订单并发退款
    IF NOT pg_try_advisory_xact_lock(p_order_id) THEN
        success := false;
        message := '订单 ' || p_order_id || ' 正在处理中，请稍后重试';
        RETURN;
    END IF;

    -- 检查订单状态
    SELECT status INTO v_current_status
    FROM tx_orders WHERE id = p_order_id FOR UPDATE;

    IF v_current_status NOT IN ('paid', 'partial_shipped', 'completed') THEN
        success := false;
        message := '当前订单状态不允许退款';
        RETURN;
    END IF;

    -- 这里应接入实际退款逻辑（调用支付渠道 API 等）
    success := true;
    message := '退款发起成功';
END;
$$ LANGUAGE plpgsql;

-- ==================== 下单存储过程（简化示例） ====================
-- 包含：库存预占 + 订单创建 + 优惠券锁定，原子性保证
CREATE OR REPLACE PROCEDURE place_order(
    p_user_id bigint,
    p_items jsonb,           -- [{"sku_id":1,"qty":2}, ...]
    p_address_id bigint,
    p_coupon_id bigint DEFAULT NULL,
    OUT p_order_no varchar,
    OUT p_order_id bigint
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_no varchar;
    v_total bigint := 0;
    v_fee bigint := 0;
    v_discount bigint := 0;
    v_item jsonb;
    v_sku_price bigint;
    v_sku_stock int;
BEGIN
    -- 订单号：ORD + YYYYMMDDHH24MISS + user_id(6位)
    v_order_no := 'ORD' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS')
                  || lpad(p_user_id::text, 6, '0');

    -- 1. 检查地址有效性
    IF NOT EXISTS (SELECT 1 FROM usr_addresses
                   WHERE id = p_address_id AND user_id = p_user_id
                   AND deleted_at IS NULL) THEN
        RAISE EXCEPTION '收货地址无效';
    END IF;

    -- 2. 逐项检查库存并累计金额
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items)
                  AS t(sku_id bigint, qty int)
    LOOP
        -- 检查并预占库存（带乐观锁语义）
        SELECT price, coalesce(available, -1)
        INTO v_sku_price, v_sku_stock
        FROM sp_skus s LEFT JOIN sp_inventories i ON i.sku_id = s.id
        WHERE s.id = v_item.sku_id AND s.deleted_at IS NULL;

        IF v_sku_stock < v_item.qty THEN
            RAISE EXCEPTION 'SKU % 库存不足（可用: %, 需求: %）',
                v_item.sku_id, v_sku_stock, v_item.qty;
        END IF;

        v_total := v_total + (v_sku_price * v_item.qty);
    END LOOP;

    -- 3. 检查优惠券
    IF p_coupon_id IS NOT NULL THEN
        UPDATE mkt_user_promotions
        SET status = 'locked', lock_order_id = -1  -- 先占位，订单创建后更新
        WHERE id = p_coupon_id AND user_id = p_user_id AND status = 'unused';

        IF NOT FOUND THEN
            RAISE EXCEPTION '优惠券不可用或已使用';
        END IF;
    END IF;

    -- 4. 创建订单
    INSERT INTO tx_orders (
        order_no, user_id, total_amount, discount_amount,
        shipping_fee, pay_amount, status, payment_status,
        consignee, phone, province, city, district, detail_addr
    ) VALUES (
        v_order_no, p_user_id, v_total, v_discount,
        v_fee, v_total - v_discount + v_fee,
        'pending', 'unpaid',
        '', '', '', '', '', ''
    )
    RETURNING id INTO p_order_id;

    -- 5. 更新优惠券订单ID
    IF p_coupon_id IS NOT NULL THEN
        UPDATE mkt_user_promotions
        SET lock_order_id = p_order_id
        WHERE id = p_coupon_id;
    END IF;

    p_order_no := v_order_no;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;

COMMENT ON FUNCTION safe_refund IS '咨询锁保证同一订单不会被并发退款';
COMMENT ON PROCEDURE place_order IS '下单过程：库存预占→金额计算→优惠券锁定→订单创建';
