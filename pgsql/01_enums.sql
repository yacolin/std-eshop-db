-- ============================================================
-- 01_enums.sql — PostgreSQL ENUM 类型定义
-- 替代 smallint / varchar 状态码
-- 必须优先于所有建表脚本加载
-- 幂等执行（已存在的 ENUM 不会重复创建）
-- ============================================================

DO $$
BEGIN
    -- ==================== 用户域 ====================
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_status')      THEN CREATE TYPE user_status      AS ENUM ('active', 'disabled', 'frozen'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'gender')           THEN CREATE TYPE gender           AS ENUM ('unknown', 'male', 'female'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'register_source')  THEN CREATE TYPE register_source  AS ENUM ('web', 'ios', 'android', 'admin'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'login_method')     THEN CREATE TYPE login_method     AS ENUM ('password', 'sms', 'oauth'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'address_tag')      THEN CREATE TYPE address_tag      AS ENUM ('home', 'office', 'company', 'other'); END IF;

    -- ==================== 商家域 ====================
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_status')    THEN CREATE TYPE merchant_status    AS ENUM ('pending', 'active', 'frozen', 'cancelled'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'audit_status')       THEN CREATE TYPE audit_status       AS ENUM ('pending', 'approved', 'rejected'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_type')      THEN CREATE TYPE merchant_type      AS ENUM ('individual', 'enterprise', 'brand_direct'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_level')     THEN CREATE TYPE merchant_level     AS ENUM ('normal', 'silver', 'gold', 'diamond'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'settlement_cycle')   THEN CREATE TYPE settlement_cycle   AS ENUM ('t1', 't7', 'monthly'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'account_type')       THEN CREATE TYPE account_type       AS ENUM ('corporate', 'personal'); END IF;

    -- ==================== 商品域 ====================
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'product_status')     THEN CREATE TYPE product_status     AS ENUM ('draft', 'pending_review', 'listed', 'delisted', 'banned'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'input_type')         THEN CREATE TYPE input_type         AS ENUM ('text', 'radio', 'checkbox', 'number'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inventory_status')   THEN CREATE TYPE inventory_status   AS ENUM ('instock', 'lowstock', 'outofstock'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'warehouse_type')     THEN CREATE TYPE warehouse_type     AS ENUM ('platform', 'merchant', 'third_party'); END IF;

    -- ==================== 交易域 ====================
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status')       THEN CREATE TYPE order_status       AS ENUM ('pending', 'paid', 'partial_shipped', 'shipped', 'delivered', 'completed', 'cancelled', 'closed', 'refunding', 'refunded'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status')     THEN CREATE TYPE payment_status     AS ENUM ('unpaid', 'paying', 'paid', 'failed', 'refunding', 'refunded'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method')     THEN CREATE TYPE payment_method     AS ENUM ('wechat', 'alipay', 'wallet'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'deliver_status')     THEN CREATE TYPE deliver_status     AS ENUM ('pending', 'picked', 'shipped', 'delivering', 'delivered', 'returned'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'after_sale_type')    THEN CREATE TYPE after_sale_type    AS ENUM ('refund', 'return', 'exchange'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'refund_status')      THEN CREATE TYPE refund_status      AS ENUM ('pending', 'processing', 'success', 'failed', 'rejected'); END IF;

    -- ==================== 营销域 ====================
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'promotion_status')   THEN CREATE TYPE promotion_status   AS ENUM ('draft', 'pending_active', 'active', 'paused', 'ended', 'cancelled'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'promotion_type')     THEN CREATE TYPE promotion_type     AS ENUM ('full_reduction_coupon', 'discount_coupon', 'flash_sale', 'full_amount_off', 'full_piece_off', 'member_price'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'condition_type')     THEN CREATE TYPE condition_type     AS ENUM ('no_threshold', 'by_amount', 'by_quantity', 'by_user_level'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_promo_status')  THEN CREATE TYPE user_promo_status  AS ENUM ('unused', 'locked', 'used', 'expired', 'cancelled'); END IF;

    -- ==================== 评价域 ====================
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'review_status')      THEN CREATE TYPE review_status      AS ENUM ('pending', 'approved', 'rejected', 'user_deleted', 'platform_hidden'); END IF;

    -- ==================== 通知域 ====================
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notify_channel')     THEN CREATE TYPE notify_channel     AS ENUM ('in_app', 'push', 'sms', 'email', 'wechat_template'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notify_category')    THEN CREATE TYPE notify_category    AS ENUM ('system', 'order', 'marketing', 'interaction', 'security'); END IF;
END $$;
