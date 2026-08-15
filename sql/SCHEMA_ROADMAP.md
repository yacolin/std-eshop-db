# 电商数据库 Schema 优化与完善路线图

> 目的：在当前 `sql/` 73 张表、9 大域的设计基础上，梳理**可优化项**与**业务完整性缺口**，
> 为后续迭代开发提供存档与任务清单。
> 生成日期：2026-07-13
> 配套文档：`SCHEMA_REVIEW.md`（评价）、`run.sql`（建表入口）

---

## 〇、关于"EAV 模型"的现状（回答核心问题）

当前唯一采用 **EAV（实体-属性-值）** 模型的是商品域：

| 表 | 作用 |
| --- | --- |
| `sp_attributes` / `sp_attribute_values` | 属性字典 + 属性值字典 |
| `sp_product_attributes` | SPU 级属性值（EAV，含 `attribute_value_id` 引用与 `value` 冗余） |
| `sp_sku_specs` | SKU 级规格值（EAV，决定可售单元） |
| `sp_category_attributes` | 类目→属性推荐模板 |

EAV 用于商品是因为"规格/属性是开放集、不同类目差异极大"，这是正确选型。

**其他业务域的扩展模式对比：**

| 域 | 当前扩展方式 | 评价 |
| --- | --- | --- |
| `mkt` 营销 | JSON（`benefit_config`、`promotion_snapshot`） | 文档型扩展，适合规则多变，**合理** |
| `tx` 交易 | JSON 快照（`coupon_snapshot`、`sku_spec`、`channel_response`） | 快照型，防篡改，**合理** |
| `sys` 系统 | JSON（`operation_logs.detail`） | 审计快照，**合理** |
| `mch` 商户 | 自由文本（`business_scope`）+ 固定列 | 类目/经营范围用文本，**偏弱** |
| `usr` 用户 | 固定列（`usr_infos`） | 资料字段固定，**无开放扩展** |
| `rev` 评价 | 固定维度列（`quality/logistics/service_rating`） | 维度固定，**够用** |

**结论与建议：**
1. EAV 不必推广到所有域——它不是银弹，会增加查询复杂度。仅在"属性是开放集"时使用（商品规格已覆盖）。
2. 其余域统一两类扩展范式：**字典表 + JSON 快照**（已是主流），避免再出现 `business_scope` 这类自由文本。
3. 若未来需要"商户自定义资料字段 / 用户自定义标签"，可新建轻量 EAV（如 `usr_user_tags`、`mch_merchant_attrs`），但当前阶段优先级低，不建议现在做。

---

## 一、跨域 / 架构级优化（影响全局）

### 1.1 分布式 ID 与分库分表策略（高）
- 现状：`id` 全部 `BIGINT AUTO_INCREMENT`。
- 风险：多商户、后续分库分表时自增主键会冲突，且 `merchant_id`/`user_id` 作为天然分片键未文档化。
- 建议：
  - 明确分片键：`sp_*`/`tx_*`/`mch_*` 按 `merchant_id` 分片；`usr_*`/`tx_orders` 按 `user_id` 分片。
  - 新建表改用 **雪花 ID（BIGINT）** 或发号器；存量表在分片改造时迁移。
  - 在 `run.sql` 顶部或独立 `SHARDING.md` 记录分片约定。

### 1.2 库存并发扣减的乐观锁（高）
- 现状：`sp_inventories` 有 `CHECK(reserved<=quantity)`，但**无版本号**；`sp_inventory_logs` 靠 `uk_ref_type(reference_id, change_type)` 做幂等。
- 风险：高并发下单时，两个事务同时读旧 `quantity` 再扣减可能超卖。
- 建议：给 `sp_inventories` 增加 `version BIGINT DEFAULT 0`，扣减走
  `UPDATE ... SET quantity=quantity-?, reserved=reserved+? WHERE id=? AND version=?:` 失败即重试/失败。
  （`mch_merchant_balances`、`mkt_promotion_stocks` 已有 `version`，应统一此模式。）

### 1.3 审计字段一致性（中）
- 现状：`created_by/updated_by` 仅部分表有（mch/sp/tx 部分），而 `tx_orders`、`tx_order_items`、`tx_payments`、`rev_reviews` 等核心表**完全没有**。
- 建议：核心业务表统一补 `created_by BIGINT`、`updated_by BIGINT`；C 端产生的单子 `created_by` 填 `user_id` 或 `0`（系统）。

### 1.4 全库外键策略文档化（中，已在 SCHEMA_REVIEW 记录）
- 现状：0 个 FK，引用完整性靠应用。
- 建议：写 `DB_CONVENTIONS.md` 明确"逻辑外键、应用自治"，并列出各关联的应用层校验点，避免后续误以为有约束。

### 1.5 日志 / 大表归档分区（低，已在 SCHEMA_REVIEW 记录）
- `tx_payment_logs`、`tx_order_logs`、`sys_operation_logs`、`sp_inventory_logs`、`tx_delivery_traces`、`mkt_promotion_usage_logs` 按 `created_at` 月度分区或定时转储冷数据。

---

## 二、各域业务完整性缺口（按域）

### 2.1 `usr` 用户域
| 缺口 | 说明 | 优先级 |
| --- | --- | --- |
| **C 端用户钱包** | `tx_payments.payment_method` 含 `wallet-余额`，但**无 `usr_wallets` / 余额流水表**。余额支付目前无法落地。 | **高** |
| **第三方登录绑定** | `usr_users` 仅有 `password_hash`，无 OAuth/微信/Apple 绑定表（`usr_user_oauth`）。 | 中 |
| **收藏 / 关注** | 无 `usr_favorites`（商品收藏）、`usr_follows`（店铺关注），电商基础能力。 | 中 |
| **签到记录** | `usr_points_rules` 有 `signin_points`，但无 `usr_signin_logs` 落地表，签到发分无法追溯/防刷。 | 中 |
| **积分余额语义** | `usr_infos.total_points`（累计）与 `usr_points.balance_after`（可用）两套口径，需明确"累计 vs 可用"，建议补 `usr_points_balances` 或文档化。 | 中 |
| **用户标签 / 分群** | 营销只能按"用户等级"圈人，缺 `usr_user_tags` 做精细化人群定向。 | 低 |

### 2.2 `sp` 商品域
| 缺口 | 说明 | 优先级 |
| --- | --- | --- |
| **采购 / 供应商** | `sp_inventories.in_transit` 暗示采购在途，但无 `sp_suppliers`、`sp_purchase_orders`，库存生命周期不完整。 | 中 |
| **多类目归属** | `sp_products.category_id` 单类目，不支持商品挂多个类目（如跨界商品）。 | 低 |
| **库存预警历史** | `sp_inventories.threshold` 有阈值但无 `sp_inventory_alerts` 预警触发记录。 | 低 |
| **商品上下架审核流** | `status` 含"待审"，但无审核日志表（可复用 `sys_operation_logs` 或新建 `sp_product_audit_logs`）。 | 低 |

### 2.3 `tx` 交易域
| 缺口 | 说明 | 优先级 |
| --- | --- | --- |
| **发票** | 无 `tx_invoices`（电子发票/抬头/税号/开票状态），B2C/B2B 常见合规需求。 | **高** |
| **组合支付 / 多次支付** | `tx_payments.order_id` 隐含"一单一付"；余额+第三方组合支付、分期付未建模。建议 `order_id` 可对应多笔 `tx_payments`。 | 中 |
| **购物车跨端合并** | `tx_carts` 有 `user_id`+`session_id`，缺合并策略落地表/字段（如 `merged_from`）。 | 低 |
| **订单状态机约束** | `status`/`payment_status`/`refund_status` 仅靠应用维护，建议补充状态流转说明文档或轻量校验。 | 低 |

### 2.4 `mkt` 营销域
| 缺口 | 说明 | 优先级 |
| --- | --- | --- |
| **签到 / 任务中心** | 见 2.1，营销侧缺"签到/每日任务"发放入口表。 | 中 |
| **积分商城 / 兑换** | `usr_points` 只进不出（无兑换目录 `mkt_point_products` 与兑换流水）。 | 中 |
| **拼团 / 分销** | 仅 `promo_type 3 秒杀`；缺拼团（`mkt_group_buys`）、分销员/邀请返佣（`mch_affiliates` / `mkt_shares`）。 | 中 |
| **营销活动分组** | 缺 `mkt_campaigns` 将多个 `promotions` 归拢为大促（双11）。 | 低 |
| **预算 / 优惠总控** | 缺活动级优惠金额预算上限与已用额度统计。 | 低 |
| **人群定向** | 促销适用对象仅支持"全站/分类/SPU/SKU"，缺"用户分群/标签"定向（依赖 2.1 用户标签）。 | 低 |

### 2.5 `mch` 商户域
| 缺口 | 说明 | 优先级 |
| --- | --- | --- |
| **提现费率** | `mch_merchant_withdrawals` 无手续费字段，实际提现普遍收费。 | 中 |
| **经营类目范围** | `business_scope` 自由文本，建议改为 `mch_merchant_categories`（类目白名单）。 | 低 |
| **违规 / 处罚记录** | 仅有 `avg_rating`，缺 `mch_merchant_violations`（违规扣分/处罚流水）。 | 低 |
| **分销 / 邀请关系** | 商户间、商户→用户的邀请返佣关系缺失（见 2.4 分销）。 | 低 |
| **店铺装修** | 缺店铺首页装修模板表（非核心，可后做）。 | 低 |

### 2.6 `rev` 评价域
| 缺口 | 说明 | 优先级 |
| --- | --- | --- |
| **追评** | 无"购买后追加评价"（`rev_review_replies` 是他人回复，非本人追评）。 | 中 |
| **评价举报 / 投诉** | 缺 `rev_review_reports`（风控补充）。 | 低 |
| **评价标签聚合** | `rev_review_statistics` 有星级分布，缺"好评标签"（如"物流快"）计数。 | 低 |

### 2.7 `sys` 系统域
| 缺口 | 说明 | 优先级 |
| --- | --- | --- |
| **系统参数配置** | 大量魔法数（默认佣金、各类阈值）散落，缺 `sys_config`（KV 配置）。 | 中 |
| **数据字典 / 枚举** | 各表 `TINYINT` 状态码无集中字典，建议 `sys_dict`（type/code/label）。 | 中 |
| **定时任务调度** | 多处注释提到"每日定时任务"（购物车清理、积分过期、统计校准），但无 `sys_jobs` 调度记录表。 | 中 |
| **文件 / 资源** | 资质、媒体、头像均存裸 URL，缺 `sys_files`（统一文件/对象存储管理）。 | 低 |

### 2.8 `base` 基础域
| 缺口 | 说明 | 优先级 |
| --- | --- | --- |
| **发送分发日志** | `base_notifications` 存最终内容，但无按渠道（短信/邮件/Push）的发送状态与第三方回执（`base_notification_dispatches`）。 | 中 |
| **订阅偏好** | 缺 `base_notification_preferences`（用户退订/渠道开关）。 | 低 |

---

## 三、一致性 / 规范巩固清单（已在 SCHEMA_REVIEW 详述，此处汇总）

- [ ] `created_by/updated_by` 与 `operator` 类型统一为 `BIGINT`（修复 `sp_inventories.last_counted_by`、`sp_inventory_logs.operator` 的 `VARCHAR(50)`）。
- [ ] 比率统一为"千分比 `BIGINT`"（`usr_points.points_multiplier` 的 `DECIMAL(3,2)` 改造）。
- [ ] 跨域命名统一：`rev_reviews.spu_id` → 与 `tx_*` 一致的 `product_id`。
- [ ] `mkt_promotions.promo_code` 空串唯一键冲突（生成列方案，已论证待实施）。
- [ ] `tx_delivery_traces` 复合主键 `(id, trace_time)` 评估是否简化为单主键。
- [ ] 全库外键策略写入 `DB_CONVENTIONS.md`。

---

## 四、建议落地路线（按阶段）

### P1（近期，补核心闭环，阻塞型）
1. **C 端用户钱包**（`usr_wallets` + 流水）—— 否则 `wallet` 支付方式不可用。
2. **发票表**（`tx_invoices`）—— 合规与售后闭环。
3. **库存乐观锁**（`sp_inventories.version`）—— 防超卖，生产必做。
4. **分布式 ID / 分片键约定文档** —— 越早定越好，避免后期返工。

### P2（中期，丰富营销与履约）
5. 签到记录、积分商城、拼团/分销。
6. 采购/供应商、库存预警。
7. 系统配置表、数据字典、定时任务表、文件表。
8. 审计字段统一补全。

### P3（长期，体验与精细化）
9. 收藏/关注、追评、评价标签、店铺装修、订阅偏好、发送分发日志。
10. 大表分区/归档、EAV 扩展（如需用户/商户自定义字段）。

---

## 五、一句话总评
当前 schema 已是"能跑通下单-支付-退款-售后-物流-结算-评价-营销"的完整电商骨架；
**最关键的三个缺口是：C 端钱包、发票、库存乐观锁**（均属"已有引用但无落地表/无并发保护"），
建议优先于任何新营销玩法补齐。其余多为体验与精细化运营的可选增强。
