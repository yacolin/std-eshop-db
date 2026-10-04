USE eshop_db;

-- ============================================================
-- tx_p5.sql — 订单分表辅助表（依赖 P0: tx_orders）
--
-- 订单分表方案见 gf-eshop 仓库 docs/order-sharding-design.md：
-- 按月分片（tx_orders / tx_sub_orders / tx_order_items / tx_order_logs 各加 YYYYMM 后缀），
-- 分片键是订单 created_at 的月份，四张表同键同片。
--
--   * tx_order_shard_map     主键 → 分片映射。新主键是 51 位时间编码（分钟|秒|序列），
--                            可直接反解出月份；只有迁移前的自增主键需要查这张表
--   * tx_order_daily_stats   订单日汇总。分片后看板的 COUNT/SUM 无法实时跨片聚合，
--                            改为日粒度累加 + 单表查询（与分片数无关）
--
-- 注意：分片表本身（tx_orders_202608 等）是**动态对象**，由应用按需创建
--       （gf-eshop: ./main shard --action=create --from=... --to=...），不入基线。
-- ============================================================

CREATE TABLE `tx_order_shard_map` (
    `order_id`   bigint      NOT NULL COMMENT '订单主键（迁移前的自增 id）',
    `order_no`   varchar(32) NOT NULL COMMENT '订单号',
    `shard`      varchar(6)  NOT NULL COMMENT '分片后缀，如 202608',
    `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '登记时间',
    PRIMARY KEY (`order_id`),
    KEY `idx_order_no` (`order_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单主键→分片映射（仅迁移前的老数据需要）';

CREATE TABLE `tx_order_daily_stats` (
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
