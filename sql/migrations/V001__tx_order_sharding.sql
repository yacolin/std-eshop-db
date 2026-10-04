-- 订单分表基础设施：主键去自增 + 分片映射表 + 订单日汇总表
-- ============================================================
-- 目标基线：sql/tx_p0.sql、sql/tx_p1.sql、sql/tx_p5.sql（run.sh 基线，含本次变更）
--
-- 变更说明
--   1) 去掉 tx_orders.id / tx_order_items.id 的 AUTO_INCREMENT，改为应用层生成的
--      全局唯一主键（51 位：分钟(25)|秒(6)|序列(20)）。分表后每个分片各有自己的
--      自增值会互相撞号，而 tx_payments / tx_refunds / tx_deliveries / tx_after_sales
--      用 order_id 引用订单、tx_delivery_items / tx_after_sales 用 order_item_id
--      引用订单项，所以这两张表的主键都必须是全局唯一的。
--   2) 新增 tx_order_shard_map：迁移前的自增主键不含时间位，无法反解分片，需要查表。
--   3) 新增 tx_order_daily_stats：分片后看板聚合改为日粒度累加，避免跨 36 片 fan-out。
--
-- 破坏性评估：**非破坏性**——列类型/长度/可空性/数据均不变，只去掉自增属性，
--   也未删表删列。但它是**行为变更**：去自增后任何不带 id 的 INSERT 会直接报
--   Error 1364 "Field 'id' doesn't have a default value"。这是刻意的——
--   宁可写入失败，也不要产生一个不含时间位、无法按 id 路由的脏主键。
--   ⚠️ 执行前请确认所有写入方都已显式指定主键（应用侧见 gf-eshop
--   internal/logic/orders/identity.go）。
--
-- 回滚方式（前向为主；紧急回滚由 DBA 审批后手工执行，并删除 schema_migrations 记录）
--   ALTER TABLE `tx_orders`      MODIFY COLUMN `id` bigint NOT NULL AUTO_INCREMENT COMMENT '自增主键';
--   ALTER TABLE `tx_order_items` MODIFY COLUMN `id` bigint NOT NULL AUTO_INCREMENT COMMENT '订单项ID';
--   DROP TABLE IF EXISTS `tx_order_shard_map`;
--   DROP TABLE IF EXISTS `tx_order_daily_stats`;
--   （分片表 tx_orders_YYYYMM 由应用创建，不受本迁移影响；回滚主键前需确认没有
--     已生成的时间编码主键，否则自增会与之冲突）
--
-- 生产注意：ALTER 大表会锁表/重建，请用 gh-ost / pt-online-schema-change 或在低峰期执行。
-- ============================================================

ALTER TABLE `tx_orders`
    MODIFY COLUMN `id` bigint NOT NULL COMMENT '全局唯一主键（51 位：分钟|秒|序列，由应用层生成，非自增）';

ALTER TABLE `tx_order_items`
    MODIFY COLUMN `id` bigint NOT NULL COMMENT '全局唯一主键（同上；供 tx_delivery_items / tx_after_sales 跨域引用）';

CREATE TABLE IF NOT EXISTS `tx_order_shard_map` (
    `order_id`   bigint      NOT NULL COMMENT '订单主键（迁移前的自增 id）',
    `order_no`   varchar(32) NOT NULL COMMENT '订单号',
    `shard`      varchar(6)  NOT NULL COMMENT '分片后缀，如 202608',
    `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '登记时间',
    PRIMARY KEY (`order_id`),
    KEY `idx_order_no` (`order_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单主键→分片映射（仅迁移前的老数据需要）';

CREATE TABLE IF NOT EXISTS `tx_order_daily_stats` (
    `stat_date`     date   NOT NULL COMMENT '统计日期（Asia/Shanghai）',
    `order_cnt`     bigint NOT NULL DEFAULT 0 COMMENT '下单数',
    `paid_cnt`      bigint NOT NULL DEFAULT 0 COMMENT '支付笔数',
    `refund_cnt`    bigint NOT NULL DEFAULT 0 COMMENT '退款笔数',
    `cancelled_cnt` bigint NOT NULL DEFAULT 0 COMMENT '取消数',
    `gmv`           bigint NOT NULL DEFAULT 0 COMMENT '下单金额（分）',
    `paid_amount`   bigint NOT NULL DEFAULT 0 COMMENT '实收金额（分）',
    `refund_amount` bigint NOT NULL DEFAULT 0 COMMENT '退款金额（分）',
    `updated_at`    datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (`stat_date`),
    CONSTRAINT `chk_order_daily_gmv` CHECK (`gmv` >= 0),
    CONSTRAINT `chk_order_daily_paid_amount` CHECK (`paid_amount` >= 0),
    CONSTRAINT `chk_order_daily_refund_amount` CHECK (`refund_amount` >= 0),
    CONSTRAINT `chk_order_daily_order_cnt` CHECK (`order_cnt` >= 0),
    CONSTRAINT `chk_order_daily_paid_cnt` CHECK (`paid_cnt` >= 0),
    CONSTRAINT `chk_order_daily_refund_cnt` CHECK (`refund_cnt` >= 0),
    CONSTRAINT `chk_order_daily_cancelled_cnt` CHECK (`cancelled_cnt` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单日汇总（看板数据源）';
