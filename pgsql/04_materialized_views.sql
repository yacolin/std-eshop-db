-- ============================================================
-- 04_materialized_views.sql — 物化视图
-- 预计算聚合数据，替代应用层定时任务手动维护
-- 使用 CONCURRENTLY 刷新避免阻塞查询
-- ============================================================

-- ==================== 商品评分汇总 ====================
-- 替代 sp_products.rating_count / rating_average 手动维护
CREATE MATERIALIZED VIEW mv_product_ratings AS
SELECT
    spu_id,
    COUNT(*) FILTER (WHERE status = 'approved') AS review_count,
    ROUND(AVG(overall_rating) FILTER (WHERE status = 'approved'), 2) AS avg_rating,
    CASE
        WHEN COUNT(*) FILTER (WHERE status = 'approved') = 0 THEN 0.00
        ELSE (COUNT(*) FILTER (WHERE overall_rating >= 4 AND status = 'approved')::numeric /
              NULLIF(COUNT(*) FILTER (WHERE status = 'approved'), 0) * 100)::numeric(5,2)
    END AS good_rate,
    COUNT(*) FILTER (WHERE has_media = 1 AND status = 'approved') AS media_count
FROM rev_reviews
GROUP BY spu_id;

CREATE UNIQUE INDEX idx_mv_product_ratings_spu ON mv_product_ratings (spu_id);

COMMENT ON MATERIALIZED VIEW mv_product_ratings IS '商品评分汇总（替代手动维护 rating_count/rating_average）';

-- ==================== 每日销售汇总 ====================
-- tx_orders 不含 merchant_id，按日期聚合总额
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT
    DATE(created_at) AS sale_date,
    COUNT(DISTINCT id) AS order_count,
    COALESCE(SUM(pay_amount), 0) AS total_amount,
    COALESCE(SUM(discount_amount), 0) AS total_discount,
    COALESCE(SUM(shipping_fee), 0) AS total_shipping
FROM tx_orders
WHERE status NOT IN ('cancelled', 'closed')
  AND deleted_at IS NULL
GROUP BY DATE(created_at);

CREATE UNIQUE INDEX idx_mv_daily_sales ON mv_daily_sales (sale_date);

COMMENT ON MATERIALIZED VIEW mv_daily_sales IS '每日销售汇总（平台维度，按日期分组）';

-- ==================== 商家日销售汇总 ====================
-- 基于 tx_sub_orders（含 merchant_id）按商家+日期聚合
CREATE MATERIALIZED VIEW mv_daily_merchant_sales AS
SELECT
    DATE(created_at) AS sale_date,
    merchant_id,
    COUNT(DISTINCT id) AS order_count,
    COALESCE(SUM(pay_amount), 0) AS total_amount,
    COALESCE(SUM(discount_amount), 0) AS total_discount,
    COALESCE(SUM(shipping_fee), 0) AS total_shipping
FROM tx_sub_orders
WHERE status NOT IN ('cancelled', 'closed')
  AND deleted_at IS NULL
GROUP BY DATE(created_at), merchant_id;

CREATE UNIQUE INDEX idx_mv_daily_merchant_sales ON mv_daily_merchant_sales (sale_date, merchant_id);

COMMENT ON MATERIALIZED VIEW mv_daily_merchant_sales IS '每日商家销售汇总（按商家+日期分组）';

-- ==================== 商家统计面板 ====================
CREATE MATERIALIZED VIEW mv_merchant_stats AS
SELECT
    m.id AS merchant_id,
    m.merchant_name,
    m.total_orders,
    m.total_sales,
    m.avg_rating,
    COALESCE(s.period_sales, 0) AS period_sales,
    COALESCE(s.period_orders, 0) AS period_orders
FROM mch_merchants m
LEFT JOIN (
    SELECT
        merchant_id,
        SUM(pay_amount) AS period_sales,
        COUNT(DISTINCT id) AS period_orders
    FROM tx_sub_orders
    WHERE status NOT IN ('cancelled', 'closed')
      AND deleted_at IS NULL
      AND created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY merchant_id
) s ON s.merchant_id = m.id
WHERE m.deleted_at IS NULL;

CREATE UNIQUE INDEX idx_mv_merchant_stats_id ON mv_merchant_stats (merchant_id);

COMMENT ON MATERIALIZED VIEW mv_merchant_stats IS '商家统计面板（含近30天汇总）';

-- ==================== 刷新函数 ====================
CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_ratings;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_sales;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_merchant_sales;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_merchant_stats;
    RAISE NOTICE 'All materialized views refreshed';
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_materialized_views IS '并发刷新所有物化视图';
