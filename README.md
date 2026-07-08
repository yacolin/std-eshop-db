# std-eshop-db

电商系统 MySQL 数据库初始化脚本，包含完整建表 + RBAC 种子数据。

- **MySQL 8.0+**，不含 FOREIGN KEY 约束，关联由业务层保证
- 表名统一加域前缀（`usr_`、`sp_`、`tx_`、`mch_` 等）
- 共 **62 张表**，按业务域 + 依赖层级拆分 19 个建表文件

## 快速开始

```bash
# 清理旧表 → 建全部表 → 初始化 RBAC 种子（需 root 密码）
bash run.sh

# 批量生成测试数据（商品、库存、订单等）
python sql/seed/seed_test_data.py
```

## 表域划分

| 域 | 文件 | 表数 | 说明 |
|----|------|------|------|
| base | base_p0.sql | 3 | 通知模板、通知 |
| mch | mch_p0~p2.sql | 9 | 商户、结算账户、资质、联系人、提现 |
| usr | usr_p0~p1.sql | 8 | 用户、地址、等级、积分、登录历史 |
| sp | sp_p0~p5.sql | 12 | 商品、品牌、类目、SKU、属性、库存、仓库、商品版本 |
| sys | sys_p0.sql | 6 | 员工、角色、权限、关联表 |
| tx | tx_p0~p4.sql | 15 | 购物车、订单、订单项、支付、退款、物流、售后 |
| mkt | mkt_p0~p1.sql | 5 | 促销活动、活动规则、用户优惠券 |
| rev | rev_p0~p1.sql | 4 | 评论、评论媒体、审核记录、回复 |

## RBAC 权限模型

### 角色清单

| 角色 | 权限数 | 写操作 | 预置账号 |
|------|--------|--------|---------|
| 管理员 | 98 | 全部 | admin |
| 运营人员 | 46 | 订单/商家/评论管理 | op_user |
| 商户用户 | 42 | 自营商品/订单/商家资料 | mch_user |
| 普通用户 | 32 | 购物车/订单/评论/地址 | colin（仅 C 端） |
| 内容编辑 | 31 | 商品/分类/品牌/促销 | editor |
| 客服人员 | 29 | 售后/评论处理 | spt_user |
| 数据分析师 | 26 | 全部只读 | aly_user |
| 仓库管理员 | 14 | 库存/发货 | wh_user |
| 财务人员 | 12 | 支付/退款/资金 | fin_user |

> B 端员工通过 `sys_staff` 表登录，默认密码均为 `123456`。

### 权限结构

98 个权限项划分为 10 个模块：

```
product(24)  → 产品/分类/品牌/SKU/属性 CRUD
merchant(21) → 商家/银行/联系人/资质/提现/余额
trade(17)    → 订单/购物车/支付/退款/物流
user(10)     → 用户/地址/积分/等级 CRUD
staff(8)     → 角色/权限 CRUD
review(5)    → 评论 CRUD + 审核 + 回复
base(4)      → 通知 CRUD
inventory(4) → 库存 CRUD + 预留
marketing(4) → 促销 CRUD
dashboard(1) → 仪表盘查看
```

> 完整权限说明见 [`docs/账号角色权限说明.md`](docs/账号角色权限说明.md)。

## 种子数据结构

| 表 | 数据量 |
|----|--------|
| sys_permissions | 98 |
| sys_roles | 9 |
| sys_role_permissions | 332 |
| usr_levels | 4（青铜/白银/黄金/钻石） |
| sys_staff | 9（每角色一个员工） |
| usr_users | 1（C 端消费者 colin） |
| usr_addresses | 2（公司 + 家） |

## 测试数据

```bash
python sql/seed/seed_test_data.py
```

生成模拟数据：商品、SKU、库存记录、订单、评论等（用于前端开发调试）。

## 相关项目

- **前端管理后台**：[gf-eshop-fe](../gf-eshop-fe) — Umi Max + Ant Design Pro
