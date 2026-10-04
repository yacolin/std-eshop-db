# Seed 数据治理（P2）

> 依据 `SCHEMA_ROADMAP.md` §4 事项⑦“Seed 数据治理与测试/生产数据隔离”交付。

## 1. 分层

| 层 | 内容 | 是否进生产 | 入口 |
| --- | --- | --- | --- |
| RBAC/静态基础 | `sys_permissions`(98)/`sys_roles`(9)/`sys_role_permissions`(332)/`usr_levels`(4) | 模板级（仅白名单角色） | `sql/seed/seed_rbac.sql`（run.sh 自动） |
| 演示数据 | 商品/SKU/库存/订单/支付/评论/通知模板等 | ❌ 禁止 | `python -m sql.seed.seed_test_data`（MySQL）/ `python3 -m pgsql.seed.seed_test_data --clean`（PG） |

> **订单域的「规范数据」（2026-10-04 分表改造后）**：`sql/seed/seed_order.py` 的数据形状对齐
> gf-eshop 应用层与 `P0_状态机契约.md`，而不是旧的「能插入就行」：
> 四张订单表已去 `AUTO_INCREMENT`（`sql/migrations/V001`、`V002`），种子用与
> `gf-eshop internal/logic/orders/identity.go` 相同的「分钟(25)|秒(6)|序列(20)」布局
> **显式写入主键**（< 2^53，前端 JS 不丢精度）；单号为 `ORD/SUB/PAY/RFD + YYYYMMDDHHMMSS + 6 位每秒序列`；
> 写入目标由 `order_shard_mode()` 自动选择主表 / 月分片 / 双写，四张表同键同片；
> 一个 `order_time` 同时派生单号、主键时间位与分片（单一时间基准）；
> 父订单按商家拆子订单，Σ子单金额 == 父单金额；每次状态迁移都写 `tx_order_logs`。
> `tx_order_shard_map` 只服务迁移前的旧自增主键，新数据可按 ID 反解分片，故保持为空。

## 2. 固定 seed 的版本与清理顺序

- `seed_data.py`（双库各一份）是**纯数据字典**（常量），被各域模块引用；不在业务模块里硬编码大字典。
- 清理顺序 = 依赖倒序：`sql/seed/seed_clean.py`（`clean()`）TRUNCATE 的列表必须覆盖 `seed_test_data.py` 生成的**全部**表，且顺序与建表依赖无关（TRUNCATE 无外键依赖，本库无 FK）。
- **订单域四张表（`tx_orders` / `tx_sub_orders` / `tx_order_items` / `tx_order_logs`）不硬编码表名**：分表后物理表是主表 + `_YYYYMM` 月分片 + `_legacy_YYYYMM` 归档副本（主表还可能已归档）。`clean()` 用 `ORDER_SHARD_BASES` + `list_tables_like()` **动态发现**全部物理表后逐个 TRUNCATE，避免 `TRUNCATE tx_orders` 直接报 Error 1146 或漏清月分片。
- 同理，`seed_test_data.py` 的计数块按逻辑表**跨分片汇总**（`active_order_tables`：有月分片时只取分片，dual 下不重复计数），`seed_points.py` / `seed_review.py` 读取订单数据时同样只取活跃分片，避免 dual（主表+分片）下同一订单被算两遍、评价撞 `rev_reviews` 唯一键。
- `run.sh` 的清理脚本 [`sql/00_drop_tables.sql`](00_drop_tables.sql) 会额外**动态删除** `tx_*_legacy_YYYYMM` 归档副本：它们由分表工具的 `RENAME TABLE` 产生，保留了原始 CHECK 约束名（`chk_pay_amount` 等），而 MySQL 约束名在 schema 内唯一，不删会让基线 `CREATE TABLE tx_orders` 报 `Error 3822`。月分片 `tx_*_YYYYMM` 不销毁（应用的动态对象，不入基线）。
- 若 seed 脚本写入了新表，必须同步补 `seed_clean.py` 表清单，否则 `--clean` 后残留脏数据掩盖问题。
- 验证：`--clean` 后重新生成，各表计数与 `seed_test_data.py` 尾部的统计块一致；重复执行 `--clean` 全量必须幂等（同一 DB 两次 `--clean` 结果一致）。

## 3. 可重复执行与幂等约定（重要）

- **seed 是非幂等的追加生成器**：重复执行不 `--clean` 会重复插入并撞唯一键
  （例如 `usr_levels.uk_level`）。正确姿势：
  - 首次/空库：`python -m sql.seed.seed_test_data`
  - 已有数据重生成：**必须先 `--clean`**（TRUNCATE 全部业务表）
  - 只跑单个域：`--module product` 等（同样需 `--clean` 后再跑，避免依赖旧数据）
- `--sharded-only`：生成后删除基线订单主表，回到「只有月分片」的分表终态（dual 下主表只是过渡镜像，应用跑 monthly 时不写它、会逐渐过期）。**仅当存在月分片时生效**，可重复执行；单表形态下绝不删主表。
- 入口文件头与 README 已写明该语义；CI/文档中禁止宣传“可随意重复执行”。
- RBAC seed 幂等：`seed_rbac.sql` 只负责全新库初始化，重复执行用 `INSERT IGNORE`/已存在跳过语义（随 run.sh 每次执行安全）。

## 4. 测试数据与生产数据隔离

- **生产初始化（run.sh）只执行 `seed_rbac.sql` 白名单角色 + 平台基础字典，禁止导入演示账号/弱密码/测试商品。**
- `sys_staff` 预置账号（admin/colin，密码 123456）仅存在于 `seed_rbac.sql` 的“开发/演示”段；
  生产部署必须另行下发强密码或由应用启动时置密码，禁止沿用默认弱口令。
- `seed_test_data.py`（C 端用户 colin、test_user_*、随机手机号等）**禁止在生产环境执行**；
  建议在部署工具中按环境标签（dev/staging/prod）拦截。
- 演示/测试库与生产库数据隔离靠“初始化入口分层”实现：
  生产 = `bash run.sh`；开发 = `run.sh` + `python -m sql.seed.seed_test_data --clean`。

## 5. 校验脚本

- 计数校验：`seed_test_data.py` 尾部自动打印各表行数（可 grep 断言；订单域四张表按逻辑表跨分片汇总）。
- 结构校验：`tests/test_sql_schema.py`（双库）保证 seed 脚本引用的列与 DDL 一致。
- 订单规范校验（生成后应全部成立）：
  1. 全部 `id > 2^40`（不是迁移前的自增 ID），且由 ID 反解出的时间与 `created_at` **完全相等**、月份与所在分片一致；
  2. `order_no` 内嵌的 14 位时间 == `created_at`，尾部 6 位序列 == ID 的序列位；
  3. `status` 与 `payment_status`、`paid_at`/`shipped_at`/`delivered_at`/`completed_at`/`closed_at` 严格对应，且时间轴单调；
  4. `Σ子单金额 == 父单金额`（total / discount / shipping / pay 四项）、`Σ明细 subtotal == 父单 total`、`明细 merchant_id == 子单 merchant_id`；
  5. 每个订单至少一条订单日志，日志链首条为 `'' → pending`、末条 `to_status == status` 且相邻日志首尾相接；
  6. 支付金额 == 订单实付、退款金额 == 支付金额；`tx_order_shard_map` 为空；`_legacy_YYYYMM` 副本为空；
  7. 跨分片 `id` / `order_no` / `sub_order_no` 全局唯一，`ORDER BY id` 等价于按时间排序。

## 6. 验收

- [x] 分层与入口约定（文档 + 入口注释）。
- [x] 清理顺序表覆盖所有演示表（`seed_clean.py` 与实际生成表一致，P0/P1 已核对）。
- [x] 双库 seed 通过 `--clean` 全量验证。
- [ ] 生产部署拦截策略（部署工具层，待工程环境）。
