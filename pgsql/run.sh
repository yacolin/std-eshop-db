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
echo "=== P0: 独立基础表(sys/sp) ===" >&2
echo "=== P1: 商品核心业务表 ===" >&2
echo "=== P2: 商品关联业务表 ===" >&2
echo "=== P3: 库存相关表 ===" >&2
echo "=== P4: 仓库相关表 ===" >&2

{
  cat pgsql/00_drop_tables.sql
  cat pgsql/00_init.sql
  cat pgsql/sys_p0.sql
  cat pgsql/sp_p0.sql
  cat pgsql/sp_p1.sql
  cat pgsql/sp_p2.sql
  cat pgsql/sp_p3.sql
  cat pgsql/sp_p4.sql
} | $PSQL

TOTAL=$(grep -rh "CREATE TABLE" pgsql/*.sql | wc -l | tr -d ' ')
echo "=== 完成：共创建 ${TOTAL} 张表 ===" >&2
