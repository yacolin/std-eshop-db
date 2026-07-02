#!/bin/bash
# 种子数据执行脚本
# 用法: bash sql/seed/run.sh

echo "=== 清理: 删除种子数据 ===" >&2
mysql -u root -p eshop_db < sql/seed/seed_clean.sql

echo "=== 初始化 RBAC（权限/角色/用户/地址）===" >&2
mysql -u root -p eshop_db < sql/seed/seed_rbac.sql

echo "=== 完成 ===" >&2
echo "测试数据请执行: python sql/seed/seed_test_data.py" >&2
