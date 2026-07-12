#!/bin/bash
# PostgreSQL 电商数据库完整建表脚本
# 用法: bash pgsql/run.sh
#
# 前置条件:
#   - PostgreSQL 12+（因使用 GENERATED STORED 列）
#   - 已设置 PGPASSWORD 环境变量，或本机 trust 认证
#   - 数据库 eshop_db 已存在（psql -U postgres -c "CREATE DATABASE eshop_db;"）

PSQL="psql -U postgres -d eshop_db"

echo "=== 清理: 删除所有旧表 ===" >&2
echo "=== 初始化: 创建触发器函数 ===" >&2
echo "=== P0: 独立基础表 ===" >&2
echo "=== P1: 核心业务表 ===" >&2
echo "=== P2: 关联业务表 ===" >&2
echo "=== P3: 库存相关表 ===" >&2
echo "=== P4: 仓配/售后/结算 ===" >&2
echo "=== P5: 版本/审计表 ===" >&2

{
  cat pgsql/00_drop_tables.sql
  cat pgsql/00_init.sql
  cat pgsql/base_p0.sql
  cat pgsql/usr_p0.sql
  cat pgsql/sys_p0.sql
  cat pgsql/sp_p0.sql
  cat pgsql/mch_p0.sql
  cat pgsql/usr_p1.sql
  cat pgsql/mch_p1.sql
  cat pgsql/sp_p1.sql
  cat pgsql/tx_p0.sql
  cat pgsql/mkt_p0.sql
  cat pgsql/rev_p0.sql
  cat pgsql/sp_p2.sql
  cat pgsql/tx_p1.sql
  cat pgsql/tx_p2.sql
  cat pgsql/mkt_p1.sql
  cat pgsql/rev_p1.sql
  cat pgsql/sp_p3.sql
  cat pgsql/sp_p4.sql
  cat pgsql/mch_p2.sql
  cat pgsql/tx_p3.sql
  cat pgsql/tx_p4.sql
  cat pgsql/sp_p5.sql
} | $PSQL

echo "=== 建表完成 ===" >&2
