# 电商商品域数据模型演进设计方案（V2）

> **目标**：从“能跑” → “能扛高并发、可长期演进”
> **原则**：弱外键、强服务边界、读写分离、ES 搜索
> **适用场景**：中大型电商、SaaS 商品中心、多商户平台

---

## 一、修订概述

本次修订在不推翻原有业务语义的前提下，对现有表结构进行工程级优化，重点解决以下问题：

| 问题域     | 原设计            | 新设计                     |
| ---------- | ----------------- | -------------------------- |
| 数据一致性 | 触发器 / 定时任务 | 应用层事务 + MQ 最终一致   |
| 外键约束   | 强外键            | **弱外键（仅索引）**       |
| SKU 规格   | JSON 字段         | **EAV 模型**               |
| 属性值管理 | JSON / 自由文本   | **属性值字典化**           |
| 库存安全   | 虚拟列            | **原子 SQL + 幂等流水**    |
| 商品搜索   | MySQL FULLTEXT    | **Elasticsearch 只读索引** |
| 全局编码   | 自增 ID           | **雪花 ID + 业务编码**     |
| 软删除索引 | 泛滥              | **精简 + 复合索引**        |

---

## 二、基础约定（强制规范）

1. **ID 生成**：所有 `id` 字段使用雪花算法生成，不再依赖数据库自增
2. **删除策略**：全量采用软删除，`UPDATE deleted_at` 替代 `DELETE`
3. **外键策略**：物理 `FOREIGN KEY` 全部移除，仅保留逻辑约束和索引
4. **金额单位**：统一为“分”，避免浮点数精度问题
5. **库存变更**：单行原子 SQL，禁止先 SELECT 后 UPDATE
6. **幂等设计**：所有写操作基于业务主键实现幂等
7. **读写分离**：写操作走 MySQL，读操作（搜索/列表）优先走 ES

---

## 三、表结构变更详情

### 3.1 P0 基础表（类目 / 品牌）

#### sp_categories（类目表）

```sql
-- 新增全局类目编码
ALTER TABLE sp_categories
ADD COLUMN category_code VARCHAR(32) NOT NULL DEFAULT '' COMMENT '类目编码（平台级唯一）',
ADD UNIQUE KEY uk_category_code (category_code);
```

#### sp_brands（品牌表）

```sql
-- 新增全局品牌编码
ALTER TABLE sp_brands
ADD COLUMN brand_code VARCHAR(32) NOT NULL DEFAULT '' COMMENT '品牌编码（平台级唯一）',
ADD UNIQUE KEY uk_brand_code (brand_code);
```

---

### 3.2 P1 核心业务表（SPU）

#### sp_products（SPU 主表）

**核心变更**：移除触发器维护字段，新增业务编码

```sql
CREATE TABLE `sp_products` (
  `id` bigint NOT NULL COMMENT 'SPU ID（雪花算法）',
  `spu_code` varchar(32) NOT NULL COMMENT '平台SPU编码',
  `merchant_id` bigint NOT NULL DEFAULT 0,

  `name` varchar(200) NOT NULL COMMENT '商品名称',
  `subtitle` varchar(500) DEFAULT '' COMMENT '商品副标题',
  `category_id` bigint NOT NULL COMMENT '前台主类目ID',
  `brand_id` bigint NOT NULL COMMENT '品牌ID',
  `unit` varchar(10) DEFAULT '件' COMMENT '单位',

  `main_image` varchar(512) DEFAULT '' COMMENT '主图URL',
  `images` json DEFAULT NULL COMMENT '附图JSON数组',
  `video_url` varchar(512) DEFAULT '' COMMENT '主图视频URL',

  -- ❌ 移除触发器维护字段：min_price, max_price, total_stock
  -- 价格和库存改为实时查询 SKU / Inventory

  `sales_count` int NOT NULL DEFAULT 0 COMMENT '总销量（每日聚合）',
  `rating_average` decimal(3,2) NOT NULL DEFAULT 0.00 COMMENT '平均评分',
  `rating_count` int NOT NULL DEFAULT 0 COMMENT '评价总数',

  `status` tinyint NOT NULL DEFAULT 0 COMMENT '0-草稿 1-待审 2-上架 3-下架 4-封禁',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序权重',

  `has_description` tinyint NOT NULL DEFAULT 0 COMMENT '1-有图文详情',

  `seo_title` varchar(200) DEFAULT '' COMMENT 'SEO标题',
  `seo_keywords` varchar(300) DEFAULT '' COMMENT 'SEO关键词',
  `seo_description` varchar(500) DEFAULT '' COMMENT 'SEO描述',

  `created_by` varchar(50) DEFAULT '' COMMENT '创建人',
  `updated_by` varchar(50) DEFAULT '' COMMENT '更新人',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_spu_code` (`spu_code`),
  KEY `idx_category_status_sort` (`category_id`, `status`, `sort_order`),
  KEY `idx_brand_status` (`brand_id`, `status`),
  KEY `idx_status_sales` (`status`, `sales_count`),
  KEY `idx_status_rating` (`status`, `rating_average`)
) ENGINE=InnoDB COMMENT='商品SPU主表';
```

---

### 3.3 P2 关联业务表（SKU / 属性）

#### sp_attributes（属性字典表）

**核心变更**：移除 JSON values，新增属性类型

```sql
ALTER TABLE sp_attributes
ADD COLUMN value_type tinyint NOT NULL DEFAULT 1 COMMENT '值类型：1-文本 2-数值 3-颜色',
ADD COLUMN filterable tinyint NOT NULL DEFAULT 0 COMMENT '是否参与前台筛选',
DROP COLUMN `values`;
```

#### sp_attribute_values（新增：属性值字典表）

**核心作用**：解决属性值不规范问题（如“红色”/“赤红”/“#FF0000”）

```sql
CREATE TABLE `sp_attribute_values` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `attribute_id` bigint NOT NULL COMMENT '关联属性ID',
  `value` varchar(200) NOT NULL COMMENT '属性值（如：256G、红色）',
  `numeric_value` decimal(18,4) DEFAULT NULL COMMENT '数值型值（用于区间筛选）',
  `color_hex` varchar(10) DEFAULT '' COMMENT '颜色色值（#FF0000）',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序权重',
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '1-启用 0-禁用',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_attr_value` (`attribute_id`, `value`),
  KEY `idx_attr_filter` (`attribute_id`, `status`, `numeric_value`)
) ENGINE=InnoDB COMMENT='属性值字典表';
```

#### sp_sku_specs（新增：SKU 规格值表 - EAV 核心）

**核心作用**：替代 `sp_skus.spec` JSON 字段，支持高效筛选

```sql
CREATE TABLE `sp_sku_specs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `sku_id` bigint NOT NULL COMMENT '关联SKU ID',
  `attribute_id` bigint NOT NULL COMMENT '关联属性ID',
  `attribute_value_id` bigint NOT NULL COMMENT '关联属性值ID',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '展示顺序',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sku_attr` (`sku_id`, `attribute_id`),
  KEY `idx_attr_value_sku` (`attribute_id`, `attribute_value_id`, `sku_id`)
) ENGINE=InnoDB COMMENT='SKU规格值表（EAV模型）';
```

#### sp_skus（SKU 表）

**核心变更**：移除 JSON spec，新增规格快照

```sql
CREATE TABLE `sp_skus` (
  `id` bigint NOT NULL COMMENT 'SKU ID（雪花算法）',
  `sku_code` varchar(32) NOT NULL COMMENT '平台SKU编码',
  `merchant_id` bigint NOT NULL DEFAULT 0,
  `product_id` bigint NOT NULL COMMENT '关联SPU ID',

  `barcode` varchar(50) DEFAULT NULL COMMENT '条码/EAN/UPC',

  -- ❌ 移除 spec JSON 和 spec_signature
  `spec_summary` varchar(500) DEFAULT '' COMMENT '规格文本快照（如：红色 / 256G）',

  `price` bigint NOT NULL COMMENT '销售价（分）',
  `market_price` bigint NOT NULL DEFAULT 0 COMMENT '划线价（分）',
  `cost_price` bigint NOT NULL DEFAULT 0 COMMENT '成本价（分）',

  `weight` decimal(10,2) DEFAULT 0.00 COMMENT '重量（克）',
  `volume` decimal(10,2) DEFAULT 0.00 COMMENT '体积（立方厘米）',

  `min_purchase_qty` int NOT NULL DEFAULT 1 COMMENT '最少购买数量',
  `max_purchase_qty` int NOT NULL DEFAULT 0 COMMENT '最大购买数量（0=不限）',

  `image` varchar(512) DEFAULT '' COMMENT 'SKU专属图',

  `status` tinyint NOT NULL DEFAULT 1 COMMENT '1-正常 0-禁用',

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sku_code` (`sku_code`),
  UNIQUE KEY `uk_barcode` (`barcode`),
  KEY `idx_product_status` (`product_id`, `status`)
) ENGINE=InnoDB COMMENT='SKU规格表';
```

#### sp_product_attributes（SPU 扩展属性表）

**变更**：无结构变化，但数据来源改为 `sp_attribute_values`

#### sp_product_descriptions（商品详情表）

**变更**：无结构变化

---

### 3.4 P3 库存相关表

#### sp_inventories（库存表）

**核心变更**：移除虚拟列 `available`，增加库存校验约束

```sql
CREATE TABLE `sp_inventories` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `sku_id` bigint NOT NULL COMMENT '关联SKU ID',
  `warehouse_id` bigint NOT NULL COMMENT '仓库ID',

  `quantity` bigint NOT NULL DEFAULT 0 COMMENT '物理库存总量',
  `reserved` bigint NOT NULL DEFAULT 0 COMMENT '预占库存',
  -- ❌ 移除虚拟列 available
  `in_transit` bigint NOT NULL DEFAULT 0 COMMENT '在途库存',

  `threshold` bigint NOT NULL DEFAULT 10 COMMENT '安全库存阈值',
  `max_threshold` bigint NOT NULL DEFAULT 999999 COMMENT '最大库存上限',

  `status` tinyint NOT NULL DEFAULT 1 COMMENT '1-充足 2-缺货 3-无货',

  `last_counted_at` datetime(3) DEFAULT NULL COMMENT '最后盘点时间',
  `last_counted_by` varchar(50) DEFAULT '' COMMENT '最后盘点人',

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` datetime(3) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sku_warehouse` (`sku_id`, `warehouse_id`),
  KEY `idx_warehouse_status` (`warehouse_id`, `status`),
  CONSTRAINT `chk_qty_nonnegative` CHECK (`quantity` >= 0),
  CONSTRAINT `chk_reserved_nonnegative` CHECK (`reserved` >= 0),
  CONSTRAINT `chk_reserved_lte_qty` CHECK (`reserved` <= `quantity`)
) ENGINE=InnoDB COMMENT='库存表（支持多仓库）';
```

#### sp_inventory_logs（库存流水表）

**核心变更**：增加幂等约束

```sql
ALTER TABLE sp_inventory_logs
ADD UNIQUE KEY uk_ref_type (reference_id, change_type);
```

---

### 3.5 P4/P5 辅助表

#### sp_warehouses（仓库表）

**变更**：移除外键，增加仓库编码

```sql
ALTER TABLE sp_warehouses
ADD COLUMN warehouse_code VARCHAR(32) NOT NULL DEFAULT '' COMMENT '仓库编码',
ADD UNIQUE KEY uk_warehouse_code (warehouse_code);
```

#### sp_product_versions（商品版本表）

**变更**：增加 SPU 编码，便于追溯

```sql
ALTER TABLE sp_product_versions
ADD COLUMN spu_code VARCHAR(32) NOT NULL DEFAULT '' COMMENT '关联SPU编码',
ADD KEY `idx_spu_version` (`spu_code`, `version` DESC);
```

---

## 四、高并发核心 SQL 示例

### 4.1 库存扣减（原子操作）

```sql
UPDATE sp_inventories
SET
  quantity = quantity - #{qty},
  reserved = reserved + #{qty}
WHERE
  sku_id = #{skuId}
  AND warehouse_id = #{warehouseId}
  AND quantity - reserved >= #{qty};
```

### 4.2 SKU 规格筛选（前台列表页）

```sql
SELECT sku_id
FROM sp_sku_specs
WHERE (attribute_id, attribute_value_id) IN (
  (#{colorAttrId}, #{redValueId}),
  (#{memoryAttrId}, #{256GValueId})
)
GROUP BY sku_id
HAVING COUNT(*) = 2;
```

---

## 五、架构演进：搜索分离

### 5.1 数据流向

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  MySQL  │──▶│  Binlog │──▶│   MQ    │──▶│   ES    │
│ (权威源)│    │ (Canal) │    │ (Kafka) │    │ (查询)  │
└─────────┘    └─────────┘    └─────────┘    └─────────┘
```

### 5.2 ES 索引映射（简化）

```json
{
  "spu_code": "SPU123456",
  "name": "iPhone 15 Pro",
  "category_id": 1001,
  "brand_id": 101,
  "sku_specs": [
    { "attr_id": 1, "attr_name": "颜色", "value_id": 101, "value": "深空灰" },
    { "attr_id": 2, "attr_name": "内存", "value_id": 201, "value": "256G" }
  ],
  "price": 899900,
  "sales_count": 1500
}
```

---

## 六、迁移策略（平滑上线）

1. **第一阶段**：新增表结构，老表保持不变
2. **第二阶段**：双写新老字段，数据同步校验
3. **第三阶段**：切换读流量到新表和 ES
4. **第四阶段**：停写老字段，归档历史数据

---

## 七、总结

本次演进后，商品域具备以下能力：

- ✅ **高并发安全**：库存原子操作，无超卖风险
- ✅ **高效筛选**：EAV 模型支持任意属性组合查询
- ✅ **数据规范**：属性值字典化，避免脏数据
- ✅ **弹性扩展**：读写分离，搜索与业务解耦
- ✅ **长期演进**：弱外键设计，支持分库分表

---

**文档版本**：V2.0  
**制定日期**：2026-07-09  
**适用范围**：电商商品域 V2 架构

需要我为你补充**数据迁移脚本**、**SKU发布事务伪代码**或**商品域服务拆分图**吗？
