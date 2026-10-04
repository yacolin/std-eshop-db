# std-eshop-db

电商系统 MySQL 数据库初始化脚本，包含完整建表 + RBAC 种子数据。

- **MySQL 8.0+**，不含 FOREIGN KEY 约束，关联由业务层保证
- 表名统一加域前缀（`usr_`、`sp_`、`tx_`、`mch_` 等）
- 共 **73 张表**，按业务域 + 依赖层级拆分 22 个建表文件

## 快速开始

```bash
# 1) 全新建库：清旧表 → 建全部表 → 初始化 RBAC 种子（需 root 密码）
bash run.sh

# 2) 批量生成测试数据（商品、库存、订单等；已有数据时务必先 --clean）
python -m sql.seed.seed_test_data --clean
```

> 全新 / 重建环境用 `run.sh` 即可，**不需要执行迁移**（`run.sh` 建出的 schema 即迁移基线 BASELINE）。
> seed 脚本是追加式生成器，重复执行前必须 `--clean`，否则会撞唯一键报错。

## 数据库初始化 vs Schema 迁移

仓库包含**两套互补的建库入口**，职责不同，别混淆：

| 场景 | 命令 |
| --- | --- |
| 全新建库（清表 → 建 73 表 → RBAC 种子） | `bash run.sh` |
| 全新建库后要演示数据 | `python -m sql.seed.seed_test_data --clean` |
| 对库登记迁移基线 / 应用基线后的增量迁移 | `bash sql/migrate.sh`（可加 `DB_NAME=<库名>`） |
| 只预览将登记 / 待执行的迁移（不写库） | `bash sql/migrate.sh --dry-run` |

要点：

- `run.sh` 负责**全新环境初始化**：执行 `sql/*.sql` 基线 DDL（该 schema 即 **BASELINE**，已含 P0–P2 全部治理成果）+ RBAC 种子；它不读取 `sql/migrations/`，行为与历史版本一致。
- `sql/migrate.sh` 负责迁移记录与**基线之后的增量升级**：首次对某库执行时自动写入 `version='baseline'` 记录（表示该库 == 当前基线），随后按序执行 `sql/migrations/V00N*.sql` 中尚未应用的版本，每个版本只执行一次（PG 镜像见 `pgsql/migrate.sh`）。
- `run.sh` 新建的库无需再跑 `migrate.sh`（跑也只登记 baseline、无待执行）；`migrate.sh` 的意义是**未来每次 schema 变更**新增一个 `V00N` 后，对已登记的库做前向升级。
- 目前 `sql/migrations/` 下还没有 `V00N` 文件属正常：代表尚未发生“基线之后”的变更。
- 若目标库是用**早于当前基线**的旧代码建的，历史回放已废弃——请先 `bash run.sh` 重建或手工对齐到当前 schema 后再进入迁移体系。
- 详细约定（命名 / 回滚 / 环境职责）见 [`sql/P2_Migration指南.md`](sql/P2_Migration指南.md)。

## 本地开发机重置

| 目标 | 命令 |
| --- | --- |
| 只重置演示数据（保留 schema 与月分片） | `python -m sql.seed.seed_test_data --clean` |
| 连 schema 一起重建（清表 → 建 73 表 → RBAC 种子 → 演示数据） | `bash run.sh`（提示输入 MySQL 密码）→ `python -m sql.seed.seed_test_data --clean` |
| 重置并回到「只有月分片」的分表终态（本地应用跑 `monthly` 时用这条） | 见下方三步 |

从零回到分表终态（`run.sh` 只建基线主表、**不建月分片**，所以要显式建一次）：

```bash
bash run.sh                                                        # 1) 基线：主表，无分片
python3 tools/create_order_shards.py --from 2026-07 --to 2026-10   # 2) 建月分片 → 布局变 dual
python -m sql.seed.seed_test_data --clean --sharded-only           # 3) 双写两侧 + 删主表 → monthly
```

要点：

- **分片表是应用管理的动态对象、不入基线**（`sql/tx_p5.sql` 头注释）。`run.sh` 只建基线主表；建分片要么由应用在 `monthly` 模式下写入时自动建当月，要么用 [`tools/create_order_shards.py`](tools/create_order_shards.py)（等价 `gf-eshop shard --action=create`，幂等、支持月份区间，可指向 RDS 直接跑）。
- 第 3 步前库里是**主表 + 月分片并存（dual）**：种子会自动识别为**双写**并同时写两侧，`orderShard.mode=single` 与 `monthly` 都能读到数据。`--sharded-only` 让种子生成完成后删掉 4 张主表、回到分表终态；该开关**只在存在月分片时生效**（单表形态下绝不删主表），可重复执行 —— 所以第 2 步不能省。
- `run.sh` 会**动态删除**订单域的 `tx_*_legacy_YYYYMM` 归档副本。原因：副本由分表工具的 `RENAME TABLE` 产生，`RENAME` 不重命名 CHECK 约束，副本仍占用原始约束名（`chk_pay_amount` / `chk_total_amount` …）；而 MySQL 的 CHECK 约束名在 schema 内唯一，残留副本会让基线建表直接报 `Error 3822 Duplicate check constraint name`。见 [`sql/00_drop_tables.sql`](sql/00_drop_tables.sql) 顶部说明。
- 别一次建太多空月份：订单列表/看板是**跨片 fan-out**，空分片也会被扫到。建「有数据的月份 + 当月」即可。
- 重置后自检：`python3 tools/verify_order_seed.py`（口径见 [`sql/P2_Seed治理.md`](sql/P2_Seed治理.md) §5）。

## 表域划分

| 域 | 文件 | 表数 | 说明 |
|----|------|------|------|
| base | base_p0.sql | 3 | 通知模板、通知 |
| mch | mch_p0~p2.sql | 11 | 商户、结算账户、资质、联系人、提现 |
| usr | usr_p0~p1.sql | 8 | 用户、地址、等级、积分、登录历史 |
| sp | sp_p0~p5.sql | 15 | 商品、品牌、类目、SKU、属性、库存、仓库、商品版本 |
| sys | sys_p0.sql | 9 | 员工、角色、权限、关联表 |
| tx | tx_p0~p4.sql | 15 | 购物车、订单、订单项、支付、退款、物流、售后 |
| mkt | mkt_p0~p1.sql | 6 | 促销活动、活动规则、用户优惠券 |
| rev | rev_p0~p1.sql | 6 | 评论、评论媒体、审核记录、回复 |

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
# 在仓库根目录执行（seed 使用包内相对导入，须以模块方式启动）
# 已有数据时重复生成必须先 --clean（TRUNCATE 全部演示表），否则会撞唯一键
python -m sql.seed.seed_test_data --clean
```

生成模拟数据：商品、SKU、库存记录、订单、评论等（用于前端开发调试）。

> 该命令只用于开发/演示环境，**禁止在生产执行**；分层约定见 [`sql/P2_Seed治理.md`](sql/P2_Seed治理.md)。

订单域数据是**按分表规范生成**的：四张订单表（`tx_orders` / `tx_sub_orders` / `tx_order_items` /
`tx_order_logs`）已去自增，种子用与 gf-eshop `identity.go` 相同的「分钟(25)|秒(6)|序列(20)」
布局显式写入全局唯一主键，并按 `created_at` 月份写入 `tx_*_YYYYMM` 月分片（同键同片）；
单号、状态机时间轴、订单日志、支付/退款均与 [`sql/P0_状态机契约.md`](sql/P0_状态机契约.md) 对齐。
校验口径见 [`sql/P2_Seed治理.md`](sql/P2_Seed治理.md) §5。

## 相关项目

- **前端管理后台**：[gf-eshop-fe](../gf-eshop-fe) — Umi Max + Ant Design Pro
