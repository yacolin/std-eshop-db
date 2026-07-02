# SQL 建表脚本

按业务域 + 依赖层级（p0-p4）拆分，共 19 个建表文件 + 2 个辅助脚本。

## 域划分

| 域 | 文件 | 说明 |
|---|---|---|
| base | base_p0.sql | 通知模板、通知 |
| sp | sp_p0~p4.sql | 商品、品牌、类目、SKU、库存、仓库 |
| tx | tx_p0~p3.sql | 购物车、订单、支付、退款、售后 |
| mkt | mkt_p0~p1.sql | 促销活动、规则、用户资产 |
| usr | usr_p0~p1.sql | 用户、地址、角色、权限 |
| rev | rev_p0~p1.sql | 评价、媒体、回复、审核 |
| mch | mch_p0~p2.sql | 商户、结算、提现 |

## 执行方式

```bash
# 清理旧表（反向依赖顺序）
mysql -u root -p < sql/00_drop_tables.sql

# 按依赖顺序建表
mysql -u root -p < sql/run.sql
```

## 说明

- MCH 多商户扩展字段（merchant_id、scope_type/scope_id）已直接写入 CREATE TABLE，无需 ALTER
- 不含 FOREIGN KEY 约束，关联由业务层保证
- 所有时间字段统一使用 `timestamp` 或 `datetime(3)` 精度
