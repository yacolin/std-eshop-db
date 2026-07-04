#!/bin/bash
# 电商数据库初始化脚本
# 清理旧表 -> 创建全部表 -> 初始化种子数据
# 用法: bash run.sh

MYSQL="mysql -u root -p"

echo "=== 清理: 删除所有旧表 ===" >&2
echo "=== P0(4): 创建独立基础表(base/mch/usr/sp) ===" >&2
echo "=== P1(6): 创建核心业务表(usr/mch/sp/tx/mkt/rev) ===" >&2
echo "=== P1.5(1): 创建用户等级/积分表(usr) ===" >&2
echo "=== P2(5): 创建关联业务表(sp/tx/mkt/rev) ===" >&2
echo "=== P3(1): 创建库存表(sp) ===" >&2
echo "=== P4(4): 创建扩展表(mch/sp/tx) ===" >&2
echo "=== P5(1): 创建商品版本表(sp) ===" >&2
echo "=== 种子: 清理旧数据 + 初始化 RBAC ===" >&2

{
  cat sql/00_drop_tables.sql
  cat sql/base_p0.sql sql/mch_p0.sql sql/usr_p0.sql sql/sp_p0.sql
  cat sql/usr_p1.sql sql/mch_p1.sql sql/sp_p1.sql sql/tx_p0.sql sql/mkt_p0.sql sql/rev_p0.sql
  cat sql/usr_p2.sql
  cat sql/sp_p2.sql sql/tx_p1.sql sql/tx_p2.sql sql/mkt_p1.sql sql/rev_p1.sql
  cat sql/sp_p3.sql
  cat sql/mch_p2.sql sql/sp_p4.sql sql/tx_p3.sql sql/tx_p4.sql
  cat sql/sp_p5.sql
  cat sql/seed/seed_clean.sql sql/seed/seed_rbac.sql
} | $MYSQL

TOTAL=$(grep -rh "CREATE TABLE" sql/*.sql | wc -l | tr -d ' ')
echo "=== 完成: 共创建 ${TOTAL} 张表 ===" >&2
echo "测试数据请执行: python sql/seed/seed_test_data.py" >&2
