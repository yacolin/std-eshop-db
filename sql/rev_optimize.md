# 电商评价域数据模型演进设计方案（V2）

> **目标**：从“功能完备” → “高并发可读、内容安全可控、统计实时可扩展”
> **原则**：弱外键、计数外置、内容审核异步化、读写分离
> **关联文档**：
>
> 1. 《电商商品域数据模型演进设计方案（V2）》
> 2. 《电商交易域数据模型演进设计方案（V2）》
> 3. 《电商营销域数据模型演进设计方案（V2）》

---

## 一、修订概述

评价域是电商系统的“信任基石”，也是典型的**写少读多、统计密集**场景。当前 `rev_p0.sql` 和 `rev_p1.sql` 设计覆盖了核心业务，但在**高并发计数、内容检索、数据归档及与交易域的一致性**上存在优化空间。

本次修订重点解决以下问题：

| 问题域       | 原设计                        | 新设计                       |
| ------------ | ----------------------------- | ---------------------------- |
| **ID生成**   | 数据库自增                    | **雪花算法（全局唯一）**     |
| **一致性**   | 物理外键/隐式关联             | **弱外键（逻辑关联+索引）**  |
| **高频计数** | DB字段实时更新 (`like_count`) | **Redis原子计数 + 异步落库** |
| **内容检索** | MySQL 模糊查询                | **Elasticsearch 全文索引**   |
| **冗余字段** | `latest_reply_id` (维护复杂)  | **移除，查询时聚合**         |
| **唯一约束** | `uk_order_item_user`          | **升级为业务幂等键**         |
| **软删除**   | 泛滥的 `deleted_at`           | **状态机驱动 + 审计日志**    |
| **多级回复** | 递归查询 (`parent_id`)        | **限制层级 + 冗余根ID**      |

---

## 二、基础约定（强制规范）

1. **ID 生成**：所有表的主键 `id` 改为 `BIGINT NOT NULL` 并由雪花算法生成。
2. **外键策略**：**全面移除外键（FOREIGN KEY）**，仅保留逻辑索引。
3. **计数策略**：
   - `like_count`, `reply_count` 等高频变更字段**不再强依赖DB实时更新**。
   - 采用 **Redis** (`INCR`/`DECR`) 进行实时计数，定时任务异步批量回写数据库。
4. **内容安全**：评价内容 (`content`) 入库前需经过风控/敏感词过滤，状态默认为 `0-待审核`。
5. **索引优化**：移除低区分度的 `idx_deleted_at`，利用复合索引覆盖高频查询。
6. **幂等设计**：用户评价基于 `order_item_id` 做唯一约束，防止重复提交。

---

## 三、表结构变更详情

### 3.1 P0：评价核心表（去自增、强幂等）

#### `rev_reviews`（评价主表）

**核心变更**：雪花ID、移除冗余字段、优化索引、增加风控字段

```sql
CREATE TABLE `rev_reviews` (
    `id` BIGINT NOT NULL COMMENT '评价ID（雪花算法）',
    `review_no` VARCHAR(32) NOT NULL COMMENT '评价业务单号（幂等键）',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `order_id` BIGINT NOT NULL COMMENT '订单ID（校验必须已购）',
    `order_item_id` BIGINT NOT NULL COMMENT '订单明细ID（用于区分同订单多商品）',

    -- 商品关联
    `spu_id` BIGINT NOT NULL COMMENT '商品SPU ID',
    `sku_id` BIGINT DEFAULT NULL COMMENT '商品SKU ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID',

    -- 评分
    `overall_rating` TINYINT NOT NULL COMMENT '总体评分（1-5星）',
    `quality_rating` TINYINT DEFAULT NULL COMMENT '质量评分',
    `logistics_rating` TINYINT DEFAULT NULL COMMENT '物流评分',
    `service_rating` TINYINT DEFAULT NULL COMMENT '服务评分',

    -- 内容
    `content` TEXT DEFAULT NULL COMMENT '评价文字内容',
    `content_length` SMALLINT DEFAULT 0 COMMENT '内容长度（冗余，用于筛选优质评价）',
    `is_anonymous` TINYINT DEFAULT 0 COMMENT '是否匿名 0-否 1-是',
    `has_media` TINYINT DEFAULT 0 COMMENT '是否包含媒体 0-否 1-是',

    -- 审核与风控
    `status` TINYINT DEFAULT 0 COMMENT '0-待审核 1-审核通过 2-审核拒绝 3-用户删除 4-平台屏蔽',
    `risk_level` TINYINT DEFAULT 0 COMMENT '风险等级 0-正常 1-低风险 2-高风险',
    `reject_reason` VARCHAR(200) DEFAULT NULL COMMENT '拒绝原因',
    `audited_by` BIGINT DEFAULT NULL COMMENT '审核人ID',
    `audited_at` DATETIME(3) DEFAULT NULL COMMENT '审核时间',

    -- 互动数据（仅作展示，实时数据来自Redis）
    `like_count` INT DEFAULT 0 COMMENT '点赞数（异步校准）',
    `helpful_count` INT DEFAULT 0 COMMENT '有用数（异步校准）',
    `reply_count` INT DEFAULT 0 COMMENT '回复总数（异步校准）',

    -- 审计
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_review_no` (`review_no`),
    -- ✅ 核心业务幂等：防止同一订单明细重复评价
    UNIQUE KEY `uk_order_item` (`order_item_id`),
    -- ✅ 高频查询覆盖索引
    KEY `idx_spu_status_created` (`spu_id`, `status`, `created_at`),
    KEY `idx_merchant_status` (`merchant_id`, `status`),
    KEY `idx_user_created` (`user_id`, `created_at`),
    KEY `idx_rating_status` (`overall_rating`, `status`),
    KEY `idx_audited` (`audited_at`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价主表';
```

---

### 3.2 P1：评价关联表（索引优化、结构微调）

#### 1. `rev_review_media`（评价媒体表）

**核心变更**：优化索引，增加文件元数据

```sql
CREATE TABLE `rev_review_media` (
    `id` BIGINT NOT NULL COMMENT '媒体ID（雪花算法）',
    `review_id` BIGINT NOT NULL COMMENT '关联评价ID',
    `media_type` TINYINT DEFAULT 1 COMMENT '1-图片 2-视频',
    `media_url` VARCHAR(500) NOT NULL COMMENT '媒体文件URL',
    `file_size` INT DEFAULT 0 COMMENT '文件大小（字节）',
    `width` INT DEFAULT 0 COMMENT '宽度（图片/视频）',
    `height` INT DEFAULT 0 COMMENT '高度（图片/视频）',
    `duration` INT DEFAULT 0 COMMENT '时长（视频，秒）',
    `sort_order` INT DEFAULT 0 COMMENT '排序',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (`id`),
    -- ✅ 优化：复合索引，按评价ID查询并排序
    KEY `idx_review_sort` (`review_id`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价媒体表';
```

#### 2. `rev_review_replies`（评价回复表）

**核心变更**：限制层级，增加根ID冗余，优化索引

```sql
CREATE TABLE `rev_review_replies` (
    `id` BIGINT NOT NULL COMMENT '回复ID（雪花算法）',
    `review_id` BIGINT NOT NULL COMMENT '关联评价ID',
    -- ✅ 新增：冗余根回复ID，便于查询某条评价下的所有一级回复
    `root_reply_id` BIGINT DEFAULT NULL COMMENT '根回复ID（一级回复为NULL）',
    `parent_id` BIGINT DEFAULT NULL COMMENT '父级回复ID（支持二级回复）',
    `reply_type` TINYINT DEFAULT 1 COMMENT '1-商家回复 2-用户追问 3-平台回复',
    `content` TEXT NOT NULL COMMENT '回复内容',
    `operator_id` BIGINT DEFAULT NULL COMMENT '操作人ID',
    `operator_name` VARCHAR(50) DEFAULT '' COMMENT '操作人名称（冗余，避免JOIN用户表）',
    `status` TINYINT DEFAULT 1 COMMENT '1-正常 2-隐藏 3-删除',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (`id`),
    -- ✅ 优化：查询某评价下的所有一级回复
    KEY `idx_review_root` (`review_id`, `root_reply_id`, `created_at`),
    -- ✅ 优化：查询某回复下的子回复（若有）
    KEY `idx_parent` (`parent_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价回复表（支持二级回复）';
```

**设计说明**：

- 将回复层级限制为**二级**（一级回复 + 二级追评），避免无限递归查询的性能噩梦。
- `root_reply_id` 用于快速分页查询一级回复列表。

#### 3. `rev_review_audit_logs`（评价审核日志表）

**核心变更**：增加审核快照，支持追溯

```sql
CREATE TABLE `rev_review_audit_logs` (
    `id` BIGINT NOT NULL COMMENT '主键（雪花算法）',
    `review_id` BIGINT NOT NULL COMMENT '评价ID',
    `action` VARCHAR(30) NOT NULL COMMENT '操作：submit/approve/reject/delete/shield',
    `operator_id` BIGINT DEFAULT NULL COMMENT '操作人ID',
    `operator_name` VARCHAR(50) DEFAULT '' COMMENT '操作人名称',
    `before_status` TINYINT DEFAULT NULL COMMENT '变更前状态',
    `after_status` TINYINT DEFAULT NULL COMMENT '变更后状态',
    `remark` VARCHAR(200) DEFAULT NULL COMMENT '操作备注',
    `snapshot` JSON DEFAULT NULL COMMENT '评价快照（用于回溯）',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (`id`),
    KEY `idx_review_created` (`review_id`, `created_at`),
    KEY `idx_operator_created` (`operator_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价审核日志表';
```

---

### 3.3 P2：新增统计与扩展表（应对大数据量）

#### 1. `rev_review_statistics`（新增：评价统计表）

**核心作用**：解决商品列表页“好评率”、“平均分”的高频查询问题，避免实时 `COUNT(*)` 和 `AVG()`。

```sql
CREATE TABLE `rev_review_statistics` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `target_type` TINYINT NOT NULL COMMENT '统计目标类型 1-SPU 2-商家',
    `target_id` BIGINT NOT NULL COMMENT '目标ID（SPU_ID或Merchant_ID）',

    -- 评分分布
    `rating_1_count` INT DEFAULT 0 COMMENT '1星数量',
    `rating_2_count` INT DEFAULT 0 COMMENT '2星数量',
    `rating_3_count` INT DEFAULT 0 COMMENT '3星数量',
    `rating_4_count` INT COMMENT '4星数量',
    `rating_5_count` INT DEFAULT 0 COMMENT '5星数量',

    `total_count` INT DEFAULT 0 COMMENT '总评价数',
    `avg_rating` DECIMAL(3,2) DEFAULT 0.00 COMMENT '平均评分',
    `good_rate` DECIMAL(5,2) DEFAULT 0.00 COMMENT '好评率（%）',

    -- 扩展统计
    `has_media_count` INT DEFAULT 0 COMMENT '带图评价数',
    `has_content_count` INT DEFAULT 0 COMMENT '有内容评价数',

    `last_updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_target` (`target_type`, `target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价统计表（T+1或实时增量更新）';
```

#### 2. `rev_review_usefulness`（新增：评价有用记录表）

**核心作用**：记录用户点击“有用”的行为，用于反作弊和权重计算。

```sql
CREATE TABLE `rev_review_usefulness` (
    `id` BIGINT NOT NULL COMMENT '主键（雪花算法）',
    `review_id` BIGINT NOT NULL COMMENT '评价ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_review_user` (`review_id`, `user_id`),
    KEY `idx_review` (`review_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价有用记录表（用于防刷和计数）';
```

---

## 四、关键业务流程与SQL示例

### 4.1 发表评价（幂等校验）

```sql
-- 利用唯一索引 uk_order_item 防止重复插入
INSERT INTO rev_reviews (..., order_item_id, ...)
VALUES (...)
ON DUPLICATE KEY UPDATE
status = IF(values(status) = 0, 0, status); -- 仅首次插入有效
```

### 4.2 点赞/有用（Redis + 异步）

```java
// 应用层逻辑
Long reviewId = ...;
Long userId = ...;

// 1. Redis 原子操作
Boolean isLiked = redisTemplate.opsForSet().add("review:likes:" + reviewId, userId);
if (isLiked) {
    Long count = redisTemplate.opsForSet().size("review:likes:" + reviewId);
    // 2. 发送MQ消息，异步更新 rev_reviews.like_count 或 rev_review_statistics
    mqSender.sendLikeEvent(reviewId, count);
}
```

### 4.3 商品详情页查询评价列表（高性能）

```sql
-- 查询SPU下的评价列表（无需JOIN媒体表，媒体单独加载）
SELECT
    r.id, r.review_no, r.user_id, r.is_anonymous,
    r.overall_rating, r.content, r.has_media,
    r.like_count, r.created_at
FROM rev_reviews r
WHERE r.spu_id = #{spuId}
  AND r.status = 1 -- 审核通过
ORDER BY r.created_at DESC
LIMIT #{offset}, #{pageSize};

-- 查询该评价下的媒体（N+1问题可通过IN查询优化）
SELECT review_id, media_url, sort_order
FROM rev_review_media
WHERE review_id IN (#{reviewIds})
ORDER BY review_id, sort_order;
```

---

## 五、架构演进建议

### 1. 引入Elasticsearch（评价搜索）

- **索引内容**：`rev_reviews` 的 `content`、`spu_id`、`sku_id`、`rating`、`status`、`created_at`。
- **用途**：
  - 前台：商品评价搜索（“有没有提到掉漆？”）。
  - 后台：客服/运营按关键词搜索评价。
- **同步**：通过 Canal 监听 `rev_reviews` Binlog，实时同步至 ES。

### 2. 引入对象存储（OSS/S3）

- `rev_review_media.media_url` 仅存储对象存储的 Key 或 CDN URL。
- 图片/视频的上传、压缩、转码由对象存储服务完成。

### 3. 异步统计更新

- **方案**：使用 Canal + MQ + Flink/Worker。
- **流程**：评价状态变更 -> Binlog -> MQ -> Worker 更新 `rev_review_statistics`。
- **优势**：避免 DB 在高峰期进行大量 `COUNT` 和 `SUM` 运算。

### 4. 服务拆分

- **Review Write Service**：负责评价的提交、审核、删除（写操作）。
- **Review Read Service**：负责评价列表、详情查询（读操作，对接 MySQL/ES）。
- **Review Statistics Service**：负责统计数据的计算和校准。

---

## 六、总结

本次演进后，评价域具备以下能力：

- ✅ **高并发可读**：Redis 承担计数压力，ES 承担搜索压力，DB 专注存储。
- ✅ **数据强一致**：雪花ID、唯一索引兜底，防止重复评价。
- ✅ **内容安全**：完善的风控字段和审核日志，支持合规追溯。
- ✅ **统计高效**：独立的统计表，避免实时聚合带来的性能损耗。
- ✅ **扩展性强**：二级回复结构清晰，媒体表字段丰富，适应未来业务变化。

---

**文档版本**：V2.0  
**制定日期**：2026-07-09  
**适用范围**：电商评价域 V2 架构

---

需要我为你绘制**评价域与交易域的交互时序图**（如订单完成后X天自动开放评价入口），或者详细说明**评价统计数据的实时增量更新方案**吗？
