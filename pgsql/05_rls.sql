-- ============================================================
-- 05_rls.sql — 行级安全策略（Row-Level Security）
-- 数据库层的多租户权限隔离，作为应用层权限的兜底防线
--
-- 使用方式：
--   1. 应用连接池连接 shop_app 用户（拥有所有基础权限）
--   2. 每次请求开始时设置上下文：
--      SET app.current_user_id = '456';
--      SET app.current_merchant_id = '123';
--      SET app.current_role = 'merchant';  -- 'admin'/'merchant'/'user'
--   3. RLS 策略自动根据上下文过滤数据
--
-- 注意事项：
--   - 超级用户（postgres）不受 RLS 限制
--   - PgBouncer 事务模式下 SET 命令会影响整个连接池
--     建议使用 session 模式，或每次使用后重置
-- ============================================================

-- ==================== 数据库角色定义 ====================
-- 这些角色用于 GRANT 权限和 RLS 策略匹配
-- 实际连接仍可使用单一应用用户，通过 SET 传递上下文

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shop_admin_role') THEN
        CREATE ROLE shop_admin_role;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shop_merchant_role') THEN
        CREATE ROLE shop_merchant_role;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shop_user_role') THEN
        CREATE ROLE shop_user_role;
    END IF;
END;
$$;

-- ==================== 表权限基础授权 ====================
-- 给所有角色基础读写权限（RLS 负责过滤行级数据）

GRANT USAGE ON SCHEMA public TO shop_admin_role, shop_merchant_role, shop_user_role;

-- 平台管理员：所有表的全部权限
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO shop_admin_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO shop_admin_role;

-- 商家角色：商家相关表的读写权限
GRANT SELECT, INSERT, UPDATE ON sp_products, sp_skus, sp_inventories,
      sp_inventory_logs, sp_product_attributes, sp_sku_specs,
      sp_product_descriptions, sp_product_versions, sp_warehouses, sp_warehouse_skus
      TO shop_merchant_role;
GRANT SELECT, UPDATE ON tx_sub_orders, tx_order_items, tx_deliveries, tx_delivery_items
      TO shop_merchant_role;
GRANT SELECT, UPDATE ON mch_merchant_balances, mch_merchant_withdrawals,
      mch_merchant_settlement_logs, mch_settlement_details
      TO shop_merchant_role;
GRANT SELECT, INSERT, UPDATE ON mkt_promotions, mkt_promotion_rules,
      mkt_promotion_products, mkt_promotion_stocks
      TO shop_merchant_role;
GRANT SELECT ON rev_reviews, rev_review_replies TO shop_merchant_role;

-- 用户角色：C 端用户相关表的读写权限
GRANT SELECT, INSERT, UPDATE ON usr_users, usr_infos, usr_addresses,
      usr_points TO shop_user_role;
GRANT SELECT, INSERT ON tx_orders, tx_sub_orders, tx_order_items,
      tx_payments, tx_refunds, tx_after_sales TO shop_user_role;
GRANT SELECT, INSERT ON rev_reviews, rev_review_media TO shop_user_role;
GRANT SELECT, INSERT ON tx_carts, tx_cart_items TO shop_user_role;

-- ==================== 启用 RLS ====================

-- 商家域
ALTER TABLE mch_merchants              ENABLE ROW LEVEL SECURITY;
ALTER TABLE mch_merchant_balances       ENABLE ROW LEVEL SECURITY;
ALTER TABLE mch_merchant_withdrawals    ENABLE ROW LEVEL SECURITY;
ALTER TABLE mch_merchant_settlement_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE mch_settlement_details      ENABLE ROW LEVEL SECURITY;

-- 商品域（商家隔离）
ALTER TABLE sp_products                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE sp_skus                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE sp_inventories              ENABLE ROW LEVEL SECURITY;
ALTER TABLE sp_inventory_logs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE sp_warehouses               ENABLE ROW LEVEL SECURITY;
ALTER TABLE sp_warehouse_skus           ENABLE ROW LEVEL SECURITY;

-- 交易域（用户/商家双向隔离）
ALTER TABLE tx_orders                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE tx_sub_orders               ENABLE ROW LEVEL SECURITY;
ALTER TABLE tx_order_items              ENABLE ROW LEVEL SECURITY;

-- 营销域（商家隔离）
ALTER TABLE mkt_promotions              ENABLE ROW LEVEL SECURITY;
ALTER TABLE mkt_promotion_rules         ENABLE ROW LEVEL SECURITY;
ALTER TABLE mkt_user_promotions         ENABLE ROW LEVEL SECURITY;

-- 评价域（用户/商家双向隔离）
ALTER TABLE rev_reviews                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE rev_review_replies          ENABLE ROW LEVEL SECURITY;

-- ==================== RLS 策略 ====================

-- ---------- 1. 平台管理员策略：全访问 ----------
-- (使用 FOR ALL 对所有操作生效)

CREATE POLICY admin_all_access ON mch_merchants
    FOR ALL TO shop_admin_role USING (true);
CREATE POLICY admin_all_access ON sp_products
    FOR ALL TO shop_admin_role USING (true);
CREATE POLICY admin_all_access ON sp_skus
    FOR ALL TO shop_admin_role USING (true);
CREATE POLICY admin_all_access ON tx_orders
    FOR ALL TO shop_admin_role USING (true);
CREATE POLICY admin_all_access ON tx_sub_orders
    FOR ALL TO shop_admin_role USING (true);
CREATE POLICY admin_all_access ON rev_reviews
    FOR ALL TO shop_admin_role USING (true);
-- 其他表类似，默认 opened 给 admin_role

-- ---------- 2. 商家隔离策略 ----------
-- 使用 current_setting('app.current_merchant_id') 获取当前商家 ID

CREATE POLICY merchant_isolation ON mch_merchants
    FOR ALL TO shop_merchant_role
    USING (id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON mch_merchant_balances
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON mch_merchant_withdrawals
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON mch_merchant_settlement_logs
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON mch_settlement_details
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON sp_products
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON sp_skus
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON sp_inventories
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON sp_inventory_logs
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON sp_warehouses
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON sp_warehouse_skus
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

-- 商家只能看到与自己相关的子订单（发给他们店铺的订单）
CREATE POLICY merchant_isolation ON tx_sub_orders
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON tx_order_items
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON mkt_promotions
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

CREATE POLICY merchant_isolation ON mkt_promotion_rules
    FOR ALL TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

-- 商家只能看到自己商品的评价
CREATE POLICY merchant_isolation ON rev_reviews
    FOR SELECT TO shop_merchant_role
    USING (merchant_id = current_setting('app.current_merchant_id')::bigint);

-- ---------- 3. C 端用户策略 ----------

-- 用户只能看到自己的订单
CREATE POLICY user_own_orders ON tx_orders
    FOR SELECT TO shop_user_role
    USING (user_id = current_setting('app.current_user_id')::bigint);

CREATE POLICY user_own_orders ON tx_sub_orders
    FOR SELECT TO shop_user_role
    USING (user_id = current_setting('app.current_user_id')::bigint);

CREATE POLICY user_own_orders ON tx_order_items
    FOR SELECT TO shop_user_role
    USING (false);  -- 通过父订单过滤，实际由 JOIN 限制

-- 用户只能看/修改自己的个人信息
CREATE POLICY user_own_data ON usr_users
    FOR ALL TO shop_user_role
    USING (id = current_setting('app.current_user_id')::bigint);

CREATE POLICY user_own_data ON usr_infos
    FOR ALL TO shop_user_role
    USING (user_id = current_setting('app.current_user_id')::bigint);

CREATE POLICY user_own_data ON usr_addresses
    FOR ALL TO shop_user_role
    USING (user_id = current_setting('app.current_user_id')::bigint);

CREATE POLICY user_own_data ON usr_points
    FOR SELECT TO shop_user_role
    USING (user_id = current_setting('app.current_user_id')::bigint);

-- 用户只能操作自己的购物车
CREATE POLICY user_own_cart ON tx_carts
    FOR ALL TO shop_user_role
    USING (user_id = current_setting('app.current_user_id')::bigint);

-- 用户只能看/写自己的评价
CREATE POLICY user_own_reviews ON rev_reviews
    FOR ALL TO shop_user_role
    USING (user_id = current_setting('app.current_user_id')::bigint);

-- ==================== 应用层上下文辅助函数 ====================

CREATE OR REPLACE FUNCTION set_app_context(
    p_user_id bigint DEFAULT NULL,
    p_merchant_id bigint DEFAULT NULL,
    p_role text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    IF p_user_id IS NOT NULL THEN
        PERFORM set_config('app.current_user_id', p_user_id::text, false);
    END IF;
    IF p_merchant_id IS NOT NULL THEN
        PERFORM set_config('app.current_merchant_id', p_merchant_id::text, false);
    END IF;
    IF p_role IS NOT NULL THEN
        PERFORM set_config('app.current_role', p_role, false);
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION set_app_context IS '设置应用层 RLS 上下文（当前用户/商家/角色）';

-- ==================== 上下文清理函数 ====================
-- 每次请求结束后调用，防止上下文泄露到后续请求

CREATE OR REPLACE FUNCTION reset_app_context()
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_user_id', '', false);
    PERFORM set_config('app.current_merchant_id', '0', false);
    PERFORM set_config('app.current_role', '', false);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION reset_app_context IS '清除应用层 RLS 上下文，防止跨请求泄露';

COMMENT ON TABLE mch_merchants IS '商家主表（RLS 启用：商家隔离 + 管理员全访问）';
COMMENT ON TABLE tx_orders IS '订单主表（RLS 启用：用户只能看自己的订单）';
COMMENT ON TABLE sp_products IS '商品SPU主表（RLS 启用：商家只能看自己的商品）';
