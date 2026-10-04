-- ============================================================
-- 电商数据库完整建表脚本
-- 按依赖层级分批执行：P0 → P1 → P2 → P3 → P4 → P5
-- 每个文件内表已按依赖关系排序；跨文件依赖通过分批顺序保证
--
-- 说明：
--   - sp_p4（仓库）是 sp_p3（库存）的前置，故 sp_p4 先于 sp_p3 执行
--   - 各文件头部的 P 编号仅作域内参考，本脚本以真实依赖顺序为准
--
-- 用法:
--   bash run.sh              (推荐 - 根目录唯一 Shell 入口)
--   mysql -u root -p < sql/run.sql       (仅执行建表，不包含种子清理/初始化)
-- ============================================================
USE eshop_db;

-- ========== P0: 独立基础表（无外部依赖）==========
source sql/base_p0.sql
source sql/mch_p0.sql
source sql/usr_p0.sql
source sql/sp_p0.sql
source sql/sys_p0.sql
source sql/tx_p0.sql
source sql/mkt_p0.sql
source sql/rev_p0.sql

-- ========== P1: 核心业务表（依赖 P0）==========
source sql/usr_p1.sql
source sql/mch_p1.sql
source sql/sp_p1.sql
source sql/mkt_p1.sql
source sql/rev_p1.sql
source sql/tx_p1.sql

-- ========== P2: 关联业务表（依赖 P1）==========
source sql/sp_p2.sql
source sql/mch_p2.sql
source sql/tx_p2.sql

-- ========== P3: 仓库 + 售后（仓库为库存前置，须先于库存；售后依赖 P1 订单）==========
source sql/sp_p4.sql
source sql/tx_p3.sql
source sql/sp_p3.sql

-- ========== P4: 物流配送（依赖 P1 订单明细 / P3 仓库库存）==========
source sql/tx_p4.sql

-- ========== P5: 商品版本历史表 + 订单分表辅助表（依赖 P1: products / P0: orders）==========
source sql/sp_p5.sql
source sql/tx_p5.sql
