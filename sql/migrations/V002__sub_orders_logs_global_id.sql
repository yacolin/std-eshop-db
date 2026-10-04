-- 子订单与订单日志的主键去自增：四张订单表主键统一为应用生成的全局唯一 ID
-- ============================================================
-- 目标基线：sql/tx_p0.sql、sql/tx_p1.sql（run.sh 基线，含本次变更）
--
-- 变更说明
--   去掉 tx_sub_orders.id / tx_order_logs.id 的 AUTO_INCREMENT，
--   改为应用层生成的全局唯一主键（与 tx_orders / tx_order_items 同一序列、同一布局）。
--
--   为什么 V001 漏了这两张表：当时只考虑了「被别的表引用的主键」——
--   tx_payments / tx_refunds / tx_deliveries 引用 tx_orders.id，
--   tx_delivery_items / tx_after_sales 引用 tx_order_items.id，所以只改了那两张。
--   但分表后还有**第二类前提**：分片运维工具（main shard --action=migrate / restore）
--   是按主键做「全列 upsert」的复制，要求主键在**主表与每个分片之间都不重复**。
--   实测踩到：分片表由 CREATE TABLE ... LIKE 建出、各自从 1 开始计数，
--   202610 分片的第一批子订单拿到 id 1..6，与主表的 8 月种子数据撞主键，
--   一次回灌把 6 行 8 月数据覆盖成了 10 月的内容。
--
-- 破坏性评估：**非破坏性**——列类型/长度/可空性/数据都不变，只去掉自增属性。
--   但有两个前置条件：
--     ① 应用必须已改成显式写入主键（gf-eshop 侧已同步修改），否则 INSERT 报 Error 1364；
--     ② 现存分片表里可能已有与主表重复的主键，需先人工核对/清理；否则复制工具的
--        主键冲突预检会拒绝执行（这是刻意的：宁可不复制，也不要静默覆盖无关行）。
--   分片表 tx_*_YYYYMM 由应用按 CREATE TABLE ... LIKE 创建，**本迁移不改分片表**；
--   新建或重建的分片会自然带上新结构。
--
--   运维提示：**已存在的分片表也要执行同样的 ALTER**（否则旧分片的 id 列仍带自增属性，
--   虽然应用显式写主键后不会再撞号，但结构会与基线不一致）。可用下面这段生成语句：
--
--     SELECT CONCAT('ALTER TABLE `', TABLE_NAME, '` MODIFY COLUMN `id` bigint NOT NULL COMMENT ''...'';')
--     FROM information_schema.COLUMNS
--     WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'id' AND EXTRA = 'auto_increment'
--       AND (TABLE_NAME LIKE 'tx_sub_orders%' OR TABLE_NAME LIKE 'tx_order_logs%');
--
-- 回滚（如需）
--   ALTER TABLE `tx_sub_orders` MODIFY COLUMN `id` bigint NOT NULL AUTO_INCREMENT COMMENT '子订单ID';
--   ALTER TABLE `tx_order_logs` MODIFY COLUMN `id` bigint NOT NULL AUTO_INCREMENT COMMENT '日志ID';
--   （回滚后新写入重新使用各表自增值，会与已有的全局唯一 ID 混用、且分片间重新撞号；
--     仅用于紧急恢复，恢复后需同时把应用改回旧版本）
-- ============================================================

ALTER TABLE `tx_sub_orders`
    MODIFY COLUMN `id` bigint NOT NULL COMMENT '全局唯一主键（51 位：分钟|秒|序列，由应用层生成，非自增）';

ALTER TABLE `tx_order_logs`
    MODIFY COLUMN `id` bigint NOT NULL COMMENT '全局唯一主键（同上，由应用层生成，非自增）';
