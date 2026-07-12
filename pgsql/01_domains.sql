-- ============================================================
-- 01_domains.sql — PostgreSQL DOMAIN 类型定义
-- 统一金额 / 百分比 / 评分 / 电话 / 邮箱 约束
-- 必须优先于所有建表脚本加载
-- 幂等执行（已存在的 DOMAIN 不会重复创建）
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'money_amount')    THEN CREATE DOMAIN money_amount   AS bigint       CHECK (VALUE >= 0); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'positive_money')  THEN CREATE DOMAIN positive_money AS bigint       CHECK (VALUE > 0); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'permille')        THEN CREATE DOMAIN permille       AS bigint       CHECK (VALUE >= 0 AND VALUE <= 1000); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'basis_points')    THEN CREATE DOMAIN basis_points   AS bigint       CHECK (VALUE >= 0 AND VALUE <= 10000); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rating_score')    THEN CREATE DOMAIN rating_score   AS numeric(3,2) CHECK (VALUE >= 0.00 AND VALUE <= 5.00); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'multiplier')      THEN CREATE DOMAIN multiplier     AS numeric(3,2) CHECK (VALUE >= 0.00); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'percentage')      THEN CREATE DOMAIN percentage     AS numeric(5,2) CHECK (VALUE >= 0.00 AND VALUE <= 100.00); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'phone_number')    THEN CREATE DOMAIN phone_number   AS text         CHECK (VALUE ~ '^[0-9+\-() ]{5,20}$'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'email_address')   THEN CREATE DOMAIN email_address  AS text         CHECK (VALUE ~ '^[^@]+@[^@]+\.[^@]+$'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'url_string')      THEN CREATE DOMAIN url_string     AS text         CHECK (VALUE ~ '^https?://'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'non_empty_text')  THEN CREATE DOMAIN non_empty_text AS text         CHECK (char_length(VALUE) > 0); END IF;
END $$;
