-- ============================================================
-- 电商数据库完整建表脚本
-- 按依赖层级分批执行：P0 → P1 → P2 → P3 → P4
-- 每个文件内表已按依赖关系排序
--
-- 用法:
--   bash sql/run.sh          (推荐 - 自动拼接所有文件)
--   mysql -u root -p < sql/run_all.sql   (手动 - 先跑 run.sh 生成合并文件)
-- ============================================================
USE eshop_db;

-- ========== P0: 独立基础表（无外部依赖）==========
source sql/base_p0.sql
source sql/mch_p0.sql
source sql/usr_p0.sql
source sql/sp_p0.sql

-- ========== P1: 核心业务表（依赖 P0）==========
source sql/usr_p1.sql
source sql/mch_p1.sql
source sql/sp_p1.sql
source sql/tx_p0.sql
source sql/mkt_p0.sql
source sql/rev_p0.sql

-- ========== P1.5: 用户等级/积分（依赖 P0）==========
source sql/usr_p2.sql

-- ========== P2: 关联业务表（依赖 P1）==========
source sql/sp_p2.sql
source sql/tx_p1.sql
source sql/tx_p2.sql
source sql/mkt_p1.sql
source sql/rev_p1.sql

-- ========== P3: 库存相关（依赖 P2）==========
source sql/sp_p3.sql

-- ========== P4: MCH 扩展表（依赖 P2/P3）==========
source sql/mch_p2.sql
source sql/sp_p4.sql
source sql/tx_p3.sql
source sql/tx_p4.sql

-- ========== P5: 商品版本表（依赖 P1: products）==========
source sql/sp_p5.sql
