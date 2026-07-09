# 电商交易域数据模型演进设计方案（V2）

> **目标**：从“功能完备” → “高并发安全、数据强一致、可长期演进”
> **原则**：弱外键、强幂等、业务闭环、读写分离
> **关联文档**：《电商商品域数据模型演进设计方案（V2）》

---

## 一、修订概述

本次修订在现有交易域表结构基础上，对齐商品域的优化思路，重点解决以下问题：

| 问题域     | 原设计           | 新设计                         |
| ---------- | ---------------- | ------------------------------ |
| 数据一致性 | 物理外键强依赖   | **弱外键（逻辑关联+索引）**    |
| 并发性能   | 外键检查拖慢写入 | **无外键，应用层事务控制**     |
| 资金安全   | 逻辑幂等         | **DB唯一键物理幂等**           |
| 购物车逻辑 | 聚合字段易脏读   | **纯临时容器，下单实时算价**   |
| 商品快照   | JSON孤岛         | **Summary快速展示 + JSON归档** |
| 大数据量表 | 单表存储         | **分区表/冷热分离**            |
| 状态流转   | 无约束           | **状态机逻辑 + CHECK约束**     |

---

## 二、基础约定（强制规范）

1. **ID 生成**：订单ID（`tx_orders.id`）使用雪花算法，其他子表自增ID仅作内部关联
2. **外键策略**：**全面移除外键（FOREIGN KEY）**，仅保留逻辑索引
3. **金额单位**：统一为“分”，所有金额字段增加 `CHECK (amount >= 0)`
4. **幂等设计**：支付、退款核心表增加 `idempotency_key` 非空约束
5. **快照策略**：
   - `sku_spec_summary`：用于列表/卡片快速展示（字符串）
   - `sku_spec`：用于售后维权（JSON，归档）
6. **软删除**：泛滥的 `idx_deleted_at` 索引全部移除，仅保留必要的复合索引
7. **分区策略**：`tx_delivery_traces` 按 `trace_time` 月度分区

---

## 三、表结构变更详情

### 3.1 P0：购物车与订单核心表

#### 1. `tx_carts`（购物车表）

**核心变更**：移除聚合字段，回归临时容器本质

```sql
CREATE TABLE `tx_carts` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '购物车ID',
  `user_id` bigint NOT NULL COMMENT '用户ID（已登录用户）',
  `session_id` varchar(64) DEFAULT '' COMMENT '会话ID（未登录时的临时标识）',
  -- ❌ 移除 item_count, total_amount (下单时实时计算，避免数据不一致)
  `expired_at` datetime(3) DEFAULT NULL COMMENT '过期时间',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_session_id` (`session_id`),
  KEY `idx_expired_at` (`expired_at`)
) ENGINE=InnoDB COMMENT='购物车主表（无聚合字段，下单实时算价）';
```

#### 2. `tx_orders`（订单主表）

**核心变更**：雪花ID、移除外键、增加资金约束

```sql
CREATE TABLE `tx_orders` (
  `id` bigint NOT NULL COMMENT '订单ID（雪花算法）',
  `order_no` varchar(32) NOT NULL COMMENT '父订单号',
  `user_id` bigint NOT NULL,

  `total_amount` bigint NOT NULL DEFAULT 0 COMMENT '商品总金额（分）',
  `discount_amount` bigint NOT NULL DEFAULT 0 COMMENT '优惠金额（分）',
  `shipping_fee` bigint NOT NULL DEFAULT 0 COMMENT '运费（分）',
  `pay_amount` bigint NOT NULL DEFAULT 0 COMMENT '实付金额（分）',

  `status` varchar(20) NOT NULL DEFAULT 'pending',
  `payment_status` varchar(20) NOT NULL DEFAULT 'unpaid',
  `payment_method` varchar(32) DEFAULT '',

  -- 收货地址快照
  `consignee` varchar(64) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `province` varchar(32) DEFAULT '',
  `city` varchar(32) DEFAULT '',
  `district` varchar(32) DEFAULT '',
  `detail_addr` varchar(256) DEFAULT '',
  `zip_code` varchar(10) DEFAULT '',

  `coupon_id` bigint DEFAULT NULL,
  `coupon_snapshot` json DEFAULT NULL,
  `buyer_remark` varchar(500) DEFAULT '',
  `seller_remark` varchar(500) DEFAULT '',

  `source` varchar(20) NOT NULL DEFAULT 'pc',
  `paid_at` datetime(3) DEFAULT NULL,
  `shipped_at` datetime(3) DEFAULT NULL,
  `delivered_at` datetime(3) DEFAULT NULL,
  `completed_at` datetime(3) DEFAULT NULL,
  `closed_at` datetime(3) DEFAULT NULL,

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_user_id` (`user_id`, `status`),
  KEY `idx_status` (`status`),
  KEY `idx_payment_status` (`payment_status`),
  KEY `idx_created_at` (`created_at`),
  -- ✅ 新增资金安全约束
  CONSTRAINT `chk_pay_amount` CHECK (`pay_amount` >= 0),
  CONSTRAINT `chk_total_amount` CHECK (`total_amount` >= 0)
) ENGINE=InnoDB COMMENT='订单主表（强约束，无外键）';
```

#### 3. `tx_sub_orders`（子订单表）

**核心变更**：移除外键，保留逻辑索引

```sql
CREATE TABLE `tx_sub_orders` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `sub_order_no` varchar(32) NOT NULL,
  `parent_order_id` bigint NOT NULL COMMENT '逻辑关联 tx_orders.id',
  `parent_order_no` varchar(32) NOT NULL,
  `user_id` bigint NOT NULL,
  `merchant_id` bigint NOT NULL DEFAULT 0,

  `total_amount` bigint NOT NULL DEFAULT 0,
  `discount_amount` bigint NOT NULL DEFAULT 0,
  `shipping_fee` bigint NOT NULL DEFAULT 0,
  `pay_amount` bigint NOT NULL DEFAULT 0,

  `status` varchar(20) NOT NULL DEFAULT 'pending',
  `refund_status` varchar(20) NOT NULL DEFAULT 'none',
  `seller_remark` varchar(500) DEFAULT '',

  `paid_at` datetime(3) DEFAULT NULL,
  `shipped_at` datetime(3) DEFAULT NULL,
  `delivered_at` datetime(3) DEFAULT NULL,
  `completed_at` datetime(3) DEFAULT NULL,
  `closed_at` datetime(3) DEFAULT NULL,

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sub_order_no` (`sub_order_no`),
  -- ❌ 移除外键，保留索引用于查询
  KEY `idx_parent_order_no` (`parent_order_no`),
  KEY `idx_merchant_status` (`merchant_id`, `status`),
  KEY `idx_user_status` (`user_id`, `status`),
  KEY `idx_created_at` (`created_at`),
  CONSTRAINT `chk_sub_pay_amount` CHECK (`pay_amount` >= 0)
) ENGINE=InnoDB COMMENT='子订单表（按商家拆单，无外键）';
```

---

### 3.2 P1：明细与日志表

#### 1. `tx_order_items`（订单明细表）

**核心变更**：增加 `sku_spec_summary`，对齐商品域EAV模型

```sql
CREATE TABLE `tx_order_items` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `order_id` bigint NOT NULL,
  `sub_order_id` bigint NOT NULL,
  `merchant_id` bigint NOT NULL DEFAULT 0,
  `order_no` varchar(32) NOT NULL,
  `sub_order_no` varchar(32) NOT NULL,

  `sku_id` bigint NOT NULL,
  `product_id` bigint NOT NULL,
  `sku_code` varchar(100) DEFAULT '',
  `product_name` varchar(200) NOT NULL,
  -- ✅ 新增：规格摘要（用于列表快速展示，无需解析JSON）
  `sku_spec_summary` varchar(500) DEFAULT '' COMMENT '规格摘要（如：红色 / 256G）',
  -- ✅ 保留：JSON快照（用于售后维权和详情页完整展示）
  `sku_spec` json DEFAULT NULL COMMENT '规格JSON快照（归档用）',
  `image` varchar(512) DEFAULT '',

  `price` bigint NOT NULL COMMENT '单价（分）',
  `quantity` int NOT NULL DEFAULT 1,
  `subtotal` bigint NOT NULL DEFAULT 0,

  `refund_status` varchar(20) NOT NULL DEFAULT 'none',
  `refund_amount` bigint NOT NULL DEFAULT 0,

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  KEY `idx_order_no` (`order_no`),
  KEY `idx_sku_id` (`sku_id`),
  KEY `idx_sub_order_id` (`sub_order_id`),
  CONSTRAINT `chk_subtotal` CHECK (`subtotal` >= 0)
) ENGINE=InnoDB COMMENT='订单明细表（EAV兼容：summary用于展示，JSON用于归档）';
```

#### 2. `tx_order_logs`（订单操作日志表）

**核心变更**：精简索引

```sql
CREATE TABLE `tx_order_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `order_id` bigint NOT NULL,
  `order_no` varchar(32) NOT NULL,
  `from_status` varchar(20) DEFAULT '',
  `to_status` varchar(20) NOT NULL,
  `operator` varchar(50) DEFAULT 'system',
  `operator_type` varchar(20) DEFAULT 'system',
  `note` varchar(500) DEFAULT '',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB COMMENT='订单操作日志表';
```

---

### 3.3 P2：支付与退款表（资金安全核心）

#### 1. `tx_payments`（支付单表）

**核心变更**：`idempotency_key` 非空，增加资金约束

```sql
CREATE TABLE `tx_payments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `payment_no` varchar(32) NOT NULL COMMENT '支付单号',
  `order_no` varchar(32) NOT NULL,
  `order_id` bigint NOT NULL,
  `merchant_id` bigint NOT NULL DEFAULT 0,
  `order_type` varchar(20) NOT NULL DEFAULT 'order',

  `amount` bigint NOT NULL COMMENT '支付金额（分）',
  `currency` varchar(10) NOT NULL DEFAULT 'CNY',

  `payment_method` varchar(32) NOT NULL,
  `channel` varchar(32) DEFAULT '',
  `trade_type` varchar(32) DEFAULT '',
  `transaction_id` varchar(128) DEFAULT NULL COMMENT '渠道交易号',
  -- ✅ 改为非空，确保接口幂等
  `idempotency_key` varchar(64) NOT NULL COMMENT '幂等键',

  `status` varchar(20) NOT NULL DEFAULT 'pending',
  `failure_reason` varchar(500) DEFAULT '',

  `client_ip` varchar(50) DEFAULT '',
  `expire_at` datetime(3) DEFAULT NULL,
  `paid_at` datetime(3) DEFAULT NULL,
  `notify_at` datetime(3) DEFAULT NULL,
  `channel_response` json DEFAULT NULL,

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_no` (`payment_no`),
  UNIQUE KEY `uk_idempotency_key` (`idempotency_key`),
  UNIQUE KEY `uk_transaction_id` (`transaction_id`),
  KEY `idx_order_no` (`order_no`),
  -- ✅ 合并索引，用于定时关单任务
  KEY `idx_status_expire` (`status`, `expire_at`),
  CONSTRAINT `chk_pay_amount_positive` CHECK (`amount` > 0)
) ENGINE=InnoDB COMMENT='支付单表（资金安全加固）';
```

#### 2. `tx_refunds`（退款单表）

**核心变更**：新增 `idempotency_key`，防止重复退款

```sql
CREATE TABLE `tx_refunds` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `refund_no` varchar(32) NOT NULL COMMENT '退款单号',
  `payment_no` varchar(32) NOT NULL COMMENT '逻辑关联 tx_payments.payment_no',
  `order_no` varchar(32) NOT NULL,
  `order_id` bigint NOT NULL,
  `merchant_id` bigint NOT NULL DEFAULT 0,

  `amount` bigint NOT NULL COMMENT '退款金额（分）',
  `reason` varchar(500) DEFAULT '',
  `status` varchar(20) NOT NULL DEFAULT 'pending',
  `channel_refund_id` varchar(128) DEFAULT NULL,
  `failure_reason` varchar(500) DEFAULT '',
  `channel_response` json DEFAULT NULL,

  -- ✅ 新增：退款幂等键
  `idempotency_key` varchar(64) NOT NULL COMMENT '退款幂等键',
  `applied_at` datetime(3) DEFAULT NULL,
  `success_at` datetime(3) DEFAULT NULL,
  `notify_at` datetime(3) DEFAULT NULL,

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_refund_no` (`refund_no`),
  UNIQUE KEY `uk_idempotency_key` (`idempotency_key`),
  UNIQUE KEY `uk_channel_refund_id` (`channel_refund_id`),
  KEY `idx_payment_no` (`payment_no`),
  KEY `idx_order_no` (`order_no`),
  CONSTRAINT `chk_refund_amount` CHECK (`amount` > 0)
) ENGINE=InnoDB COMMENT='退款单表（增加幂等键）';
```

---

### 3.4 P3：售后表

#### `tx_after_sales`（售后单表）

**核心变更**：状态机明确化，移除物理外键

```sql
CREATE TABLE `tx_after_sales` (
    `id` bigint NOT NULL AUTO_INCREMENT,
    `after_sale_no` varchar(32) NOT NULL,
    `order_id` bigint NOT NULL,
    `order_item_id` bigint NOT NULL,
    `merchant_id` bigint NOT NULL,
    `user_id` bigint NOT NULL,
    `after_sale_type` TINYINT NOT NULL COMMENT '1-退款 2-退货 3-换货',
    `apply_quantity` int NOT NULL DEFAULT 1,
    `reason` varchar(500) DEFAULT '',
    `amount` bigint NOT NULL DEFAULT 0 COMMENT '退款金额（分）',
    `refund_no` varchar(32) DEFAULT '' COMMENT '关联退款单号（逻辑关联）',

    -- ✅ 优化：状态枚举更清晰
    `status` TINYINT NOT NULL DEFAULT 0 COMMENT '0-待审核 1-审核通过(待退货) 2-退货中 3-待退款 4-已完成 5-已拒绝 6-已取消',

    `return_carrier` varchar(20) DEFAULT '',
    `return_tracking_no` varchar(64) DEFAULT '',
    `return_shipped_at` datetime(3) DEFAULT NULL,
    `merchant_received_at` datetime(3) DEFAULT NULL,
    `apply_at` datetime(3) DEFAULT NULL,
    `audited_at` datetime(3) DEFAULT NULL,
    `completed_at` datetime(3) DEFAULT NULL,

    `created_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` datetime(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` datetime(3) DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_after_sale_no` (`after_sale_no`),
    KEY `idx_order_item` (`order_item_id`),
    KEY `idx_merchant_status` (`merchant_id`, `status`),
    KEY `idx_user_status` (`user_id`, `status`),
    CONSTRAINT `chk_as_amount` CHECK (`amount` >= 0)
) ENGINE=InnoDB COMMENT='售后单表（状态机优化）';
```

---

### 3.5 P4：物流表

#### `tx_delivery_traces`（物流轨迹表）

**核心变更**：复合主键，建议分区

```sql
CREATE TABLE `tx_delivery_traces` (
    `id` bigint NOT NULL AUTO_INCREMENT,
    `delivery_id` bigint NOT NULL,
    `tracking_no` varchar(64) NOT NULL,
    `trace_time` datetime(3) NOT NULL,
    `location` varchar(200) DEFAULT '',
    `status` varchar(50) NOT NULL,
    `description` varchar(500) DEFAULT '',
    `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    -- ✅ 复合主键，便于按时间分区
    PRIMARY KEY (`id`, `trace_time`),
    KEY `idx_tracking_no` (`tracking_no`),
    KEY `idx_trace_time` (`trace_time`)
) ENGINE=InnoDB COMMENT='物流轨迹表（建议按 trace_time 月度分区）';
```

---

## 四、关键业务流程SQL示例

### 4.1 下单扣减库存（原子操作）

```sql
START TRANSACTION;

-- 1. 校验并扣减库存（核心）
UPDATE sp_inventories inv
JOIN tx_order_items oi ON inv.sku_id = oi.sku_id
SET inv.quantity = inv.quantity - oi.quantity,
    inv.reserved = inv.reserved + oi.quantity
WHERE oi.order_id = #{orderId}
  AND inv.warehouse_id = #{mainWarehouseId}
  AND inv.quantity - inv.reserved >= oi.quantity;

-- 2. 创建订单记录...
-- 3. 清空购物车...

COMMIT;
```

### 4.2 支付回调处理（幂等）

```sql
INSERT INTO tx_payments (..., transaction_id, idempotency_key, ...)
VALUES (..., 'WECHAT_123456', 'UUID_XXX', ...)
ON DUPLICATE KEY UPDATE
status = IF(values(status) = 'success', 'success', status);
```

---

## 五、架构演进建议

1. **服务拆分**：
   - **Order Service**：负责 `tx_orders`, `tx_sub_orders`, `tx_order_items`
   - **Payment Service**：负责 `tx_payments`, `tx_refunds`
   - **AfterSale Service**：负责 `tx_after_sales`
2. **状态机引擎**：将订单、售后状态流转接入状态机，防止非法状态跳转
3. **读写分离**：
   - **写**：MySQL（强一致）
   - **读**：订单列表、搜索走 **Elasticsearch**
4. **数据归档**：
   - 半年前的 `tx_delivery_traces` 迁移至 Hive
   - 历史订单（Completed/Closed）迁移至历史库

---

## 六、总结

本次演进后，交易域具备以下能力：

- ✅ **高并发安全**：无外键、原子库存扣减、物理幂等
- ✅ **数据强一致**：CHECK约束兜底，金额字段非负
- ✅ **业务闭环**：快照策略兼顾性能与维权
- ✅ **可扩展性**：弱外键设计，支持未来分库分表

---

**文档版本**：V2.0  
**制定日期**：2026-07-09  
**适用范围**：电商交易域 V2 架构

需要我为你绘制**商品域与交易域的交互时序图**，或详细说明**Saga分布式事务**在订单创建过程中的应用吗？
