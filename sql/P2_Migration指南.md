# Migration 体系指南（MySQL / PostgreSQL）

> 依据 `SCHEMA_ROADMAP.md` §4 事项①“Migration 体系”交付。
> 目标：schema 变更可复现、可审查、可回滚；`run.sql` 只负责全新环境初始化。
> 更新日期：2026-09-03（**以当前数据库状态为基线重写**：删除早期 V001–V003 历史回放，迁移从零重新编号）。

---

## 0. 基线定义（重要）

**当前仓库的建表脚本（`sql/*.sql` 73 表 / `pgsql/*.sql` 74 表，即 `run.sh` / `pg_run.sh` 建出的 schema）
就是迁移基线 BASELINE（版本 0）**，其中已包含 P0–P2 全部治理成果（金额 CHECK、支付词表、库存乐观锁、
资金表禁软删、DDL 收口等）。

迁移体系只负责 **BASELINE 之后** 的增量变更：

```text
BASELINE（当前 run.sh 基线，版本 0）
   └─ V001__<变更>.sql   ← 未来的第一个结构变更从这里开始编号
        └─ V002__...    ← 依此类推
```

- 迁移运行器首次对某库执行时，若 `schema_migrations` 为空/不存在，**自动登记 `version='baseline'`**
  （表示“该库 == 当前基线”）；此后新增的 V00N 才会被识别为待执行。
- 早于当前基线的旧库**不再提供自动回放**：请先用 `run.sh`/`pg_run.sh` 重建，或手工对齐到当前基线，
  再进入迁移体系。早期为 P0–P2 编写的 V001–V003 回放脚本已随基线重写删除。

## 1. 目录与文件约定

### MySQL

```
sql/
├── run.sql                     # 全新环境初始化入口（含全部基线 DDL = BASELINE，不含迁移）
├── migrate.sh                  # 迁移运行器（登记 baseline、按序执行未应用迁移）
└── migrations/
    ├── schema_migrations.sql   # 执行记录表 DDL（运行器自动执行）
    ├── README.md               # 目录说明（基线定义）
    ├── V001__<说明>.sql         # 未来第一个基线后迁移（当前尚无 = 正常）
    └── V00N__<说明>.sql         # 后续迁移（禁止修改已发布文件）
```

### PostgreSQL

```
pgsql/
├── run.sql                     # 全新环境初始化入口（含基线 + PG 高级特性）
├── migrate.sh                  # 迁移运行器（同 MySQL 语义）
└── migrations/
    ├── schema_migrations.sql
    ├── README.md
    ├── V001__...sql            # 未来第一个基线后迁移（当前尚无 = 正常）
    └── V00N__...sql
```

> PG 侧既有 `pgsql/MIGRATION_GUIDE.md` 描述的是“旧 schema → 当前 PG schema”的一次性就地迁移
> （ENUM/DOMAIN/分区改造），与本体系互补：本体系管**基线之后每次增量变更**。

## 2. 命名与版本

- 文件名：`V<3位序号>__<snake_case 说明>.sql`（如 `V001__sp_warehouse_sku_index.sql`）。
- 版本号从 **V001 单调递增**，不允许重排 / 修改已应用文件；同一文件只执行一次
  （`schema_migrations.version` 主键保证）。
- 每个文件头写：目标基线、变更说明、回滚方式。
- 新增迁移时**同时**更新基线 `sql/*.sql`（供全新库）与迁移文件（供存量库），两路结果保持一致
  （可跑 `tools/schema_diff.py` 验证二者终态一致）。

## 3. 执行流程

```bash
# MySQL（默认 eshop_db；首次执行自动登记 baseline）
bash sql/migrate.sh
DB_NAME=my_db bash sql/migrate.sh
bash sql/migrate.sh --dry-run

# PostgreSQL
bash pgsql/migrate.sh            # 默认 eshop_db；可用 DB_NAME / PGUSER / PGPASSWORD 覆盖
```

运行器行为：
1. 确保 `schema_migrations` 表存在；
2. 若表为空/不存在（首次）→ 登记 `version='baseline'`（当前基线，checksum 为空）；
3. 计算已应用版本集合，按文件名顺序执行 **baseline 之后**未应用 `V*.sql`；
4. 每个迁移成功后插入执行记录（version/file/description/checksum/executor/耗时）；
5. 任一迁移失败即中断（`set -e`），人工修复后重跑——已成功部分不会重复执行。

## 4. 环境职责划分（重要）

| 环境 | 初始化方式 | 迁移策略 |
| --- | --- | --- |
| 全新环境（空库） | `bash run.sh`（MySQL）/ `bash pg_run.sh` 或 pgsql/run.sql | 该库即 BASELINE；首次 `migrate.sh` 只登记 baseline，无待执行 |
| 当前基线存量库 | `run.sh` 建出或已手工对齐 | 每次 `migrate.sh` 应用尚未执行的 V00N 增量 |
| 早于当前基线的旧库 | 旧代码建出 | **不提供自动回放**：先重建（run.sh/pg_run.sh）或手工对齐到当前基线 |
| 只读从库/快照 | 与主库同源 | 与主库保持相同 schema 版本 |

> 全新库与“基线 + 逐条迁移”两种路径终态一致：全新库由 run.sql 一次到位；
> 存量库从登记 baseline 起，仅应用后续新增迁移，不会重复执行历史内容。

## 5. 回滚约定

- **常规回滚**：不直接修改历史迁移，而是新增 `V00N+1` 做反向变更（前向迁移原则）。
- **紧急回滚**：在 DBA 审批下用文件头标注的反向 SQL 手动执行，并删除 `schema_migrations` 对应记录；
  回滚脚本命名建议 `<V00N>_down_<说明>.sql` 放同目录（仅归档不自动执行）。
- 破坏性变更（删列/删表/改类型）必须显式标注 `-- DESTRUCTIVE`，并先在 P2 SQL lint / review 通过。

## 6. 与 P2 其他治理的关系

- 每个新迁移提交前跑 `sql_lint.py`（见 `sql/P2_SQLlint规范.md`），CI 上跑 `schema_diff` 对比
  （基线变更前后应能一一对应到新迁移）。
- 对账/复核脚本（`sql/audit/*`、`pgsql/audit/*`）在新迁移后可作回归验证。

## 7. 验收清单

- [x] 版本化迁移目录 + 执行记录表（MySQL & PG）
- [x] 升级运行器（migrate.sh，双库），首次执行自动登记 baseline
- [x] 以当前 schema 为基线：迁移从 V001 重新编号，历史回放脚本已删除
- [x] 回滚约定（前向为主 + down 脚本归档）
- [x] run.sql 仅保留全新环境初始化职责（未挂入迁移）
- [x] 实测：全新基线库 `migrate.sh` = 登记 baseline 且无待执行（双库）
