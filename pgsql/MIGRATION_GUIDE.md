# PostgreSQL 特性改造 — 数据迁移指南

> 已有数据的数据库迁移到此新 schema 的操作步骤。
> 适用于 `pg_dump`/`pg_restore` 之外的就地迁移（in-place migration）场景。

---

## 目录

1. [迁移概览](#1-迁移概览)
2. [前置条件](#2-前置条件)
3. [ENUM 类型迁移](#3-enum-类型迁移)
4. [DOMAIN 类型迁移](#4-domain-类型迁移)
5. [索引替换](#5-索引替换)
6. [表分区迁移](#6-表分区迁移)
7. [物化视图创建](#7-物化视图创建)
8. [排他约束添加](#8-排他约束添加)
9. [迁移回滚](#9-迁移回滚)
10. [迁移检查清单](#10-迁移检查清单)

---

## 1. 迁移概览

本次改造涉及以下变更类型：

| 变更 | 向下兼容 | 可回滚 | 执行时间 |
|------|:-------:|:-----:|:-------:|
| ENUM 类型替换 | ❌ | ✅ | 分钟级 |
| DOMAIN 类型 | ✅ | ✅ | 分钟级 |
| 部分索引替换 | ✅ | ✅ | 分钟级 |
| 表分区 | ✅* | ✅ | 小时级 |
| 物化视图 | ✅ | ✅ | 分钟级 |
| 排他约束 | ✅ | ✅ | 分钟级 |
| 乐观锁加列 | ✅ | ✅ | 秒级 |

\* 表分区迁移需在线重建（pg_repack）或维护窗口

---

## 2. 前置条件

```sql
-- 备份
pg_dump -U postgres -d eshop_db --format=custom -f eshop_db_pre_migration.dump

-- 确认 PG 版本（至少 12+ 以支持分区表 GENERATED 列）
SHOW server_version;
```

---

## 3. ENUM 类型迁移

### 3.1 创建 ENUM 类型（在事务中执行）

```sql
BEGIN;

-- 创建所有 ENUM 类型（幂等）
\i pgsql/01_enums.sql

-- usr_users.status: smallint → user_status
ALTER TABLE usr_users ALTER COLUMN status TYPE user_status USING
    CASE status
        WHEN 1 THEN 'active'::user_status
        WHEN 0 THEN 'disabled'::user_status
        WHEN 2 THEN 'frozen'::user_status
    END;

-- mch_merchants.status: smallint → merchant_status
ALTER TABLE mch_merchants ALTER COLUMN status TYPE merchant_status USING
    CASE status
        WHEN 0 THEN 'pending'::merchant_status
        WHEN 1 THEN 'active'::merchant_status
        WHEN 2 THEN 'frozen'::merchant_status
        WHEN 3 THEN 'cancelled'::merchant_status
    END;

-- mch_merchants.audit_status: smallint → audit_status
ALTER TABLE mch_merchants ALTER COLUMN audit_status TYPE audit_status USING
    CASE audit_status
        WHEN 0 THEN 'pending'::audit_status
        WHEN 1 THEN 'approved'::audit_status
        WHEN 2 THEN 'rejected'::audit_status
    END;

-- mch_merchants.merchant_type: smallint → merchant_type
ALTER TABLE mch_merchants ALTER COLUMN merchant_type TYPE merchant_type USING
    CASE merchant_type
        WHEN 1 THEN 'individual'::merchant_type
        WHEN 2 THEN 'enterprise'::merchant_type
        WHEN 3 THEN 'brand_direct'::merchant_type
    END;

-- mch_merchants.merchant_level: smallint → merchant_level
ALTER TABLE mch_merchants ALTER COLUMN merchant_level TYPE merchant_level USING
    CASE merchant_level
        WHEN 1 THEN 'normal'::merchant_level
        WHEN 2 THEN 'silver'::merchant_level
        WHEN 3 THEN 'gold'::merchant_level
        WHEN 4 THEN 'diamond'::merchant_level
    END;

-- sp_products.status: smallint → product_status
ALTER TABLE sp_products ALTER COLUMN status TYPE product_status USING
    CASE status
        WHEN 0 THEN 'draft'::product_status
        WHEN 1 THEN 'pending_review'::product_status
        WHEN 2 THEN 'listed'::product_status
        WHEN 3 THEN 'delisted'::product_status
        WHEN 4 THEN 'banned'::product_status
    END;

-- mkt_promotions.status: smallint → promotion_status
ALTER TABLE mkt_promotions ALTER COLUMN status TYPE promotion_status USING
    CASE status
        WHEN 1 THEN 'draft'::promotion_status
        WHEN 2 THEN 'pending_active'::promotion_status
        WHEN 3 THEN 'active'::promotion_status
        WHEN 4 THEN 'paused'::promotion_status
        WHEN 5 THEN 'ended'::promotion_status
        WHEN 6 THEN 'cancelled'::promotion_status
    END;

-- mkt_promotions.promo_type: smallint → promotion_type
ALTER TABLE mkt_promotions ALTER COLUMN promo_type TYPE promotion_type USING
    CASE promo_type
        WHEN 1 THEN 'full_reduction_coupon'::promotion_type
        WHEN 2 THEN 'discount_coupon'::promotion_type
        WHEN 3 THEN 'flash_sale'::promotion_type
        WHEN 4 THEN 'full_amount_off'::promotion_type
        WHEN 5 THEN 'full_piece_off'::promotion_type
        WHEN 6 THEN 'member_price'::promotion_type
    END;

-- rev_reviews.status: smallint → review_status
ALTER TABLE rev_reviews ALTER COLUMN status TYPE review_status USING
    CASE status
        WHEN 0 THEN 'pending'::review_status
        WHEN 1 THEN 'approved'::review_status
        WHEN 2 THEN 'rejected'::review_status
        WHEN 3 THEN 'user_deleted'::review_status
        WHEN 4 THEN 'platform_hidden'::review_status
    END;

-- tx_orders.status: varchar → order_status（已有文本值，直接转换）
ALTER TABLE tx_orders ALTER COLUMN status TYPE order_status USING status::order_status;

-- tx_orders.payment_status: varchar → payment_status
ALTER TABLE tx_orders ALTER COLUMN payment_status TYPE payment_status USING payment_status::payment_status;

-- tx_payments.status: varchar → payment_status
ALTER TABLE tx_payments ALTER COLUMN status TYPE payment_status USING
    CASE status
        WHEN 'pending' THEN 'unpaid'::payment_status
        WHEN 'processing' THEN 'paying'::payment_status
        WHEN 'success' THEN 'paid'::payment_status
        WHEN 'failed' THEN 'failed'::payment_status
        WHEN 'refunding' THEN 'refunding'::payment_status
        WHEN 'refunded' THEN 'refunded'::payment_status
    END;

-- tx_payments.payment_method: varchar → payment_method
ALTER TABLE tx_payments ALTER COLUMN payment_method TYPE payment_method USING payment_method::payment_method;

-- tx_refunds.status: varchar → refund_status
ALTER TABLE tx_refunds ALTER COLUMN status TYPE refund_status USING status::refund_status;

-- sp_inventories.status: varchar → inventory_status
ALTER TABLE sp_inventories ALTER COLUMN status TYPE inventory_status USING status::inventory_status;

-- base_notifications.channel: smallint → notify_channel
ALTER TABLE base_notifications ALTER COLUMN channel TYPE notify_channel USING
    CASE channel
        WHEN 1 THEN 'in_app'::notify_channel
        WHEN 2 THEN 'push'::notify_channel
        WHEN 3 THEN 'sms'::notify_channel
        WHEN 4 THEN 'email'::notify_channel
        WHEN 5 THEN 'wechat_template'::notify_channel
    END;

-- base_notifications.category: smallint → notify_category
ALTER TABLE base_notifications ALTER COLUMN category TYPE notify_category USING
    CASE category
        WHEN 1 THEN 'system'::notify_category
        WHEN 2 THEN 'order'::notify_category
        WHEN 3 THEN 'marketing'::notify_category
        WHEN 4 THEN 'interaction'::notify_category
        WHEN 5 THEN 'security'::notify_category
    END;

COMMIT;
```

### 3.2 更新默认值

```sql
-- 将旧 schema 中定义的 numeric 默认值更新为新 ENUM 默认值
ALTER TABLE usr_users       ALTER COLUMN status       SET DEFAULT 'active';
ALTER TABLE mch_merchants   ALTER COLUMN status       SET DEFAULT 'pending';
ALTER TABLE mch_merchants   ALTER COLUMN audit_status SET DEFAULT 'pending';
ALTER TABLE sp_products     ALTER COLUMN status       SET DEFAULT 'draft';
ALTER TABLE rev_reviews     ALTER COLUMN status       SET DEFAULT 'pending';
```

---

## 4. DOMAIN 类型迁移

DOMAIN 类型内建了 CHECK 约束，仅对新插入/更新的数据生效，已有数据不会自动校验：

```sql
-- 示例：将 tx_orders 金额列改为 money_amount DOMAIN
-- 注意：已有数据需先通过检查
ALTER TABLE tx_orders
    ALTER COLUMN pay_amount TYPE money_amount USING pay_amount::money_amount,
    ALTER COLUMN total_amount TYPE money_amount USING total_amount::money_amount,
    ALTER COLUMN discount_amount TYPE money_amount USING discount_amount::money_amount,
    ALTER COLUMN shipping_fee TYPE money_amount USING shipping_fee::money_amount;

-- 评分列
ALTER TABLE rev_reviews
    ALTER COLUMN overall_rating TYPE rating_score USING overall_rating::rating_score;
```

---

## 5. 索引替换

### 5.1 删除旧索引 + 创建部分索引

```sql
-- 批量替换所有 deleted_at 全量索引为部分索引
-- 以下为模板，实际执行时逐表操作

-- 示例：usr_users
DROP INDEX IF EXISTS idx_usr_users_deleted_at;
CREATE INDEX idx_usr_users_active ON usr_users (status, id) WHERE deleted_at IS NULL;
```

### 5.2 创建 BRIN 索引（表数据量大时需注意）

```sql
-- BRIN 索引适用于 append-only 的日志表
-- 对已有大表创建 BRIN 索引可能较慢，建议在维护窗口执行
CREATE INDEX CONCURRENTLY idx_tx_order_logs_time_brin
    ON tx_order_logs USING BRIN (created_at) WITH (pages_per_range = 32);
```

---

## 6. 表分区迁移

> **建议方法：使用 pg_repack 或维护窗口重建。**  
> PG 不支持将普通表直接 ALTER 为分区表。需通过以下方式之一：

### 方法 A：维护窗口 — 重建并迁移数据（推荐）

```sql
-- 1. 创建分区表
CREATE TABLE usr_login_histories_new (
    LIKE usr_login_histories INCLUDING DEFAULTS INCLUDING CONSTRAINTS
) PARTITION BY RANGE (created_at);

-- 2. 创建分区
CREATE TABLE usr_login_histories_202607 PARTITION OF usr_login_histories_new
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
-- ... 创建所有需要的历史分区

-- 3. 迁移数据
INSERT INTO usr_login_histories_new SELECT * FROM usr_login_histories;

-- 4. 加索引
CREATE INDEX ON usr_login_histories_new (user_id);

-- 5. 替换表
ALTER TABLE usr_login_histories RENAME TO usr_login_histories_old;
ALTER TABLE usr_login_histories_new RENAME TO usr_login_histories;
DROP TABLE usr_login_histories_old;
```

### 方法 B：使用 pg_repack（零停机）

```bash
# 安装 pg_repack
# 在线重建表为分区结构（结合方法A的分区表准备步骤）
pg_repack -U postgres -d eshop_db --table usr_login_histories
```

---

## 7. 物化视图创建

```sql
-- 物化视图为全新创建，无迁移问题
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_ratings;
REFRESH MATERIALIZED VIEW CONCULLENTLY mv_daily_sales;
```

---

## 8. 排他约束添加

```sql
-- 需先确保已有数据不违反约束
-- 检查是否有重叠促销
SELECT a.id, b.id, a.merchant_id
FROM mkt_promotions a, mkt_promotions b
WHERE a.id < b.id
  AND a.merchant_id = b.merchant_id
  AND a.start_time < b.end_time
  AND a.end_time > b.start_time
  AND a.status IN ('active', 'pending_active')
  AND b.status IN ('active', 'pending_active')
  AND a.deleted_at IS NULL
  AND b.deleted_at IS NULL;

-- 无重叠数据后可添加约束
-- 注：excl_promo_no_overlap 已在建表脚本中定义
-- 如需要单独添加：
-- ALTER TABLE mkt_promotions ADD CONSTRAINT excl_promo_no_overlap
--     EXCLUDE USING GIST (merchant_id WITH =, active_period WITH &&)
--     WHERE (deleted_at IS NULL AND status IN ('active', 'pending_active'));
```

---

## 9. 迁移回滚

```sql
-- 回滚 ENUM 为 smallint（数据会丢失类型信息，但可恢复）
BEGIN;
ALTER TABLE usr_users ALTER COLUMN status TYPE smallint USING
    CASE status
        WHEN 'active' THEN 1
        WHEN 'disabled' THEN 0
        WHEN 'frozen' THEN 2
    END;
-- ... 其他表同理
DROP TYPE IF EXISTS user_status CASCADE;
-- ... 其他 ENUM 同理
COMMIT;
```

---

## 10. 迁移检查清单

- [ ] `pg_dump` 全量备份完成
- [ ] PG 版本 ≥ 12（分区表 + GENERATED 列要求）
- [ ] 所有依赖扩展已安装（pg_trgm、btree_gist、uuid-ossp）
- [ ] ENUM 迁移 USING 子句覆盖所有旧值
- [ ] 测试环境 full dry-run 通过
- [ ] 种子数据已适配新类型（Python seed scripts）
- [ ] BRIN 索引在已有大表上使用 CONCURRENTLY
- [ ] 分区迁移验证数据完整性（COUNT 对比）
- [ ] 物化视图首次 REFRESH 完成
- [ ] 排他约束排除已有冲突数据
- [ ] 应用连接池配置（LISTEN/NOTIFY 需要非 PgBouncer 事务模式）
- [ ] 监控：索引大小变化、查询计划变化
