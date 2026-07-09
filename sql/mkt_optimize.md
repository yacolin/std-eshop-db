# 电商营销域数据模型演进设计方案（V2）

> **目标**：从“功能完备” → “高并发抗抢购、规则强一致、资产可追溯”
> **原则**：弱外键、规则配置化、资产独立化、读写分离
> **关联文档**：
>
> 1. 《电商商品域数据模型演进设计方案（V2）》
> 2. 《电商交易域数据模型演进设计方案（V2）》

---

## 一、修订概述

营销域是电商系统的“CPU”，也是高并发的聚集地（如秒杀、百亿补贴）。当前设计虽然涵盖了核心业务，但在**高并发下的数据一致性、规则扩展性、资产安全性**上存在隐患。

本次修订重点解决以下问题：

| 问题域       | 原设计                    | 新设计                          |
| ------------ | ------------------------- | ------------------------------- |
| **ID生成**   | 数据库自增                | **雪花算法（全局唯一）**        |
| **一致性**   | 物理外键强依赖            | **弱外键（逻辑关联+索引）**     |
| **高并发**   | 行锁竞争（库存扣减）      | **Redis原子预扣 + MQ异步落地**  |
| **规则配置** | 字段固化（benefit_value） | **JSON化（支持阶梯满减/折扣）** |
| **资产安全** | 逻辑删除                  | **状态机 + 幂等凭证**           |
| **查询性能** | MySQL 范围扫描            | **ES 倒排索引（用户券列表）**   |
| **库存隔离** | 通用库存字段              | **专用库存表（防超卖）**        |

---

## 二、基础约定（强制规范）

1. **ID 生成**：所有表的主键 `id` 改为 `BIGINT NOT NULL` 并由雪花算法生成。
2. **外键策略**：**全面移除外键（FOREIGN KEY）**，仅保留逻辑索引。
3. **金额单位**：统一为“分”，`condition_value`, `benefit_value`, `discount_amount` 均为分。
4. **库存扣减**：
   - 缓存层：Redis `DECR` 原子操作。
   - 数据库层：`UPDATE ... SET stock = stock - 1 WHERE stock > 0;`
5. **软删除**：移除无意义的 `idx_deleted_at`，改为利用 `status` 或 `end_time` 过滤。
6. **幂等设计**：用户领券、核销必须基于唯一业务键。

---

## 三、表结构变更详情

### 3.1 P0：促销核心表（去自增、强约束）

#### `mkt_promotions`（统一促销活动表）

**核心变更**：ID策略变更、增加库存表关联、优化索引

```sql
CREATE TABLE `mkt_promotions` (
    `id` BIGINT NOT NULL COMMENT '促销ID（雪花算法）',
    `promotion_no` VARCHAR(32) NOT NULL COMMENT '促销业务编号',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID（0表示平台级活动）',
    `promo_name` VARCHAR(100) NOT NULL COMMENT '活动名称',
    `promo_type` TINYINT NOT NULL COMMENT '1-满减券 2-折扣券 3-秒杀 4-满额减 5-满件折 6-会员价',
    `promo_code` VARCHAR(50) DEFAULT '' COMMENT '优惠码（优惠券专用）',

    -- 时间范围
    `start_time` DATETIME(3) NOT NULL COMMENT '开始时间',
    `end_time` DATETIME(3) NOT NULL COMMENT '结束时间',

    -- 库存限制（引用专用库存表，此处仅冗余显示）
    `total_quantity` INT DEFAULT 0 COMMENT '发行总量（0表示不限）',
    `per_user_limit` INT DEFAULT 1 COMMENT '每人限领/限购数量',
    `used_quantity` INT DEFAULT 0 COMMENT '已使用/已售数量（异步统计，非实时）',

    -- 规则引用
    `rule_id` BIGINT NOT NULL COMMENT '关联规则表ID',

    -- 状态
    `status` TINYINT DEFAULT 1 COMMENT '1-草稿 2-待生效 3-生效中 4-已暂停 5-已结束 6-已作废',

    -- 优先级（用于叠加计算）
    `priority` INT DEFAULT 0 COMMENT '优先级（数字越大越优先，同类型互斥）',

    -- 审计字段
    `created_by` BIGINT COMMENT '创建人',
    `updated_by` BIGINT COMMENT '更新人',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` DATETIME(3) DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_promotion_no` (`promotion_no`),
    UNIQUE KEY `uk_promo_code` (`promo_code`),
    KEY `idx_merchant_status_time` (`merchant_id`, `status`, `start_time`, `end_time`),
    KEY `idx_type_status` (`promo_type`, `status`),
    KEY `idx_rule_id` (`rule_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='统一促销活动表';
```

---

### 3.2 P1：规则、商品与资产（配置化、资产化）

#### 1. `mkt_promotion_rules`（促销规则表）

**核心变更**：规则JSON化，支持复杂计算

```sql
CREATE TABLE `mkt_promotion_rules` (
    `id` BIGINT NOT NULL COMMENT '规则ID（雪花算法）',
    `promotion_id` BIGINT NOT NULL COMMENT '所属促销ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',
    `rule_name` VARCHAR(100) COMMENT '规则名称',

    -- 触发条件
    `condition_type` TINYINT NOT NULL COMMENT '1-无门槛 2-满金额 3-满件数 4-指定用户等级',
    `condition_value` BIGINT NOT NULL DEFAULT 0 COMMENT '门槛值（分）',

    -- ✅ 优化：优惠内容JSON化（支持阶梯）
    `benefit_config` JSON NOT NULL COMMENT '优惠配置JSON。例：{"type":1,"value":3000} 或 {"type":2,"steps":[{"limit":10000,"rate":900},{"limit":20000,"rate":800}]}',

    -- 叠加规则
    `is_stackable` TINYINT DEFAULT 0 COMMENT '是否可与其他促销叠加 0-否 1-是',
    `stack_group` INT DEFAULT 0 COMMENT '叠加组ID（同组内互斥，不同组可叠加）',

    -- 审计字段
    `created_by` BIGINT COMMENT '创建人',
    `updated_by` BIGINT COMMENT '更新人',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` DATETIME(3) DEFAULT NULL,

    PRIMARY KEY (`id`),
    KEY `idx_promotion` (`promotion_id`),
    KEY `idx_stack_group` (`stack_group`, `is_stackable`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='促销规则表（配置化）';
```

#### 2. `mkt_promotion_products`（促销适用商品表）

**核心变更**：移除无用索引，增加复合索引

```sql
CREATE TABLE `mkt_promotion_products` (
    `id` BIGINT NOT NULL COMMENT '主键ID（雪花算法）',
    `promotion_id` BIGINT NOT NULL COMMENT '促销ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',
    `product_type` TINYINT NOT NULL COMMENT '1-全站 2-指定分类 3-指定SPU 4-指定SKU',
    `target_id` BIGINT COMMENT '目标ID（SPU_ID或SKU_ID或Category_ID）',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `deleted_at` DATETIME(3) DEFAULT NULL,

    PRIMARY KEY (`id`),
    -- ✅ 优化：覆盖索引，用于判断商品是否参与活动
    UNIQUE KEY `uk_promotion_target` (`promotion_id`, `product_type`, `target_id`),
    KEY `idx_target` (`target_id`, `product_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='促销适用商品表';
```

#### 3. `mkt_user_promotions`（用户促销资产表）

**核心变更**：增加库存预留字段，优化状态机

```sql
CREATE TABLE `mkt_user_promotions` (
    `id` BIGINT NOT NULL COMMENT '主键ID（雪花算法）',
    `user_promotion_no` VARCHAR(32) NOT NULL COMMENT '用户促销资产编号',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `promotion_id` BIGINT NOT NULL COMMENT '促销ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',

    -- 领取/获取信息
    `acquire_time` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) COMMENT '领取时间',
    `expire_time` DATETIME(3) COMMENT '过期时间',

    -- 使用状态
    `status` TINYINT DEFAULT 1 COMMENT '1-未使用 2-锁定中(下单未付) 3-已使用 4-已过期 5-已作废',
    `lock_order_id` BIGINT DEFAULT NULL COMMENT '锁定的订单ID（用于回滚）',
    `used_time` DATETIME(3) COMMENT '使用时间',
    `order_id` BIGINT COMMENT '最终使用的订单ID',

    -- 秒杀专用
    `queue_token` VARCHAR(64) DEFAULT '' COMMENT '秒杀排队令牌',

    -- 审计字段
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` DATETIME(3) DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_promotion_no` (`user_promotion_no`),
    -- ✅ 优化：用户可用券查询（最高频查询）
    KEY `idx_user_available` (`user_id`, `status`, `expire_time`),
    KEY `idx_promotion` (`promotion_id`),
    KEY `idx_lock_order` (`lock_order_id`),
    KEY `idx_order` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户促销资产表（状态机优化）';
```

---

### 3.3 P2：库存与日志（高并发安全）

#### 1. `mkt_promotion_stocks`（新增：促销库存表）

**核心作用**：隔离促销库存与活动信息，支持高并发扣减

```sql
CREATE TABLE `mkt_promotion_stocks` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `promotion_id` BIGINT NOT NULL COMMENT '促销ID',
    `sku_id` BIGINT DEFAULT NULL COMMENT 'SKU ID（秒杀专用，通用活动可为空）',
    `total_stock` INT NOT NULL DEFAULT 0 COMMENT '总库存',
    `available_stock` INT NOT NULL DEFAULT 0 COMMENT '可用库存',
    `locked_stock` INT NOT NULL DEFAULT 0 COMMENT '锁定库存（下单未付）',
    `version` INT NOT NULL DEFAULT 0 COMMENT '乐观锁版本号',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_promotion_sku` (`promotion_id`, `sku_id`),
    CONSTRAINT `chk_stock_positive` CHECK (`available_stock` >= 0 AND `locked_stock` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='促销库存表（支持秒杀）';
```

#### 2. `mkt_promotion_usage_logs`（促销使用记录表）

**核心变更**：精简字段，增加分表建议

```sql
CREATE TABLE `mkt_promotion_usage_logs` (
    `id` BIGINT NOT NULL COMMENT '主键ID（雪花算法）',
    `promotion_id` BIGINT NOT NULL COMMENT '促销ID',
    `user_promotion_id` BIGINT DEFAULT NULL COMMENT '用户促销资产ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `order_id` BIGINT NOT NULL COMMENT '使用的订单ID',

    -- 使用信息
    `discount_amount` BIGINT NOT NULL DEFAULT 0 COMMENT '优惠金额（分）',

    -- 快照信息（用于财务对账）
    `promotion_snapshot` JSON DEFAULT NULL COMMENT '优惠快照（名称、规则等）',

    -- 审计字段
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`),
    KEY `idx_order` (`order_id`),
    KEY `idx_promotion_created` (`promotion_id`, `created_at`),
    KEY `idx_user_created` (`user_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='促销使用记录表（建议按 created_at 月度分区）';
```

---

## 四、关键业务流程SQL示例

### 4.1 秒杀/抢券库存扣减（数据库层）

```sql
-- 利用乐观锁和库存校验，防止超卖
UPDATE mkt_promotion_stocks
SET
    available_stock = available_stock - 1,
    version = version + 1
WHERE
    promotion_id = #{promotionId}
    AND available_stock > 0
    AND version = #{version}; -- 乐观锁校验
```

### 4.2 下单优惠锁定（状态机流转）

```sql
-- 将用户的优惠券从未使用置为锁定中
UPDATE mkt_user_promotions
SET
    status = 2, -- 2: 锁定中
    lock_order_id = #{orderId}
WHERE
    user_promotion_no = #{userPromotionNo}
    AND user_id = #{userId}
    AND status = 1; -- 1: 未使用
```

### 4.3 支付失败回滚

```sql
-- 释放锁定的优惠券
UPDATE mkt_user_promotions
SET
    status = 1, -- 1: 未使用
    lock_order_id = NULL
WHERE
    lock_order_id = #{orderId}
    AND status = 2;
```

---

## 五、架构演进建议

### 1. 引入规则引擎

由于 `benefit_config` 采用了 JSON 结构，建议在上层封装**规则计算器（Rule Calculator）**，避免将复杂的阶梯计算逻辑散落在业务代码中。

### 2. Redis 缓存设计

- **Key**: `promo:stock:{promotionId}:{skuId}`
- **Value**: Integer (Available Stock)
- **预热**: 活动开始前，将 `mkt_promotion_stocks` 加载至 Redis。
- **扣减**: 使用 `DECR` 原子操作，返回成功后才放行至数据库。

### 3. 读写分离

- **写**：MySQL（强一致）
- **读**：
  - 用户券列表：`Redis` + `ES`（按用户ID、状态、过期时间查询）
  - 商品可用券：`Redis`（Key: `promo:active:sku:{skuId}`）

### 4. 服务拆分

- **Promotion Admin Service**: 负责活动配置、规则管理。
- **Promotion Calculation Service**: 负责下单时的价格计算（无状态，可横向扩展）。
- **Coupon Asset Service**: 负责用户券的发放、核销、过期（状态机核心）。

---

## 六、总结

本次演进后，营销域具备以下能力：

- ✅ **高并发安全**：独立库存表 + Redis 原子操作，杜绝超卖。
- ✅ **规则灵活**：JSON 配置化，支持阶梯满减、循环优惠等复杂场景。
- ✅ **资产安全**：完善的资产状态机（未使用 -> 锁定 -> 已使用/回滚）。
- ✅ **数据一致**：移除物理外键，通过逻辑索引和事务保证一致性。

---

**文档版本**：V2.0  
**制定日期**：2026-07-09  
**适用范围**：电商营销域 V2 架构

---

需要我为你补充**营销域与交易域在计算优惠时的交互时序图**，或者详细说明**Redis缓存与数据库库存的一致性保障方案**吗？
