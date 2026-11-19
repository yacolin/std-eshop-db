# sql/migrations 迁移目录说明

> 基线定义：**当前仓库 `sql/*.sql`（`run.sh` 建出的 schema，74 张表）即为迁移基线 BASELINE**。
> 更新日期：2026-11-19（新增 V003 搜索词日志表；此前 2026-09-03 迁移体系以当前数据库状态为基线重写）。

## 版本模型

```
BASELINE（当前 run.sh 基线，版本 0）
   └─ V001__<变更>.sql   ← 未来第一个结构变更从这里开始编号
        └─ V002__...    ← 依此类推
```

- 基线之后的每个结构变更：**先改 `sql/*.sql`（供全新库 run.sh）**，再**新增 `sql/migrations/V00N__*.sql`**（供已部署库前向升级），两路结果保持一致。
- 当前已有 **V001**（订单分表基础设施）、**V002**（子订单/订单日志主键去自增）、
  **V003**（搜索词日志表）：基线之后的增量变更。
- 早期曾有一批 P0/P1/P2 历史回放文件（当时也编号为 V001–V003，与当前 V001~V003 **无关**），
  因变更已直接并入当前基线、不再需要从旧基线回放，已删除。

## 文件

| 文件 | 作用 |
| --- | --- |
| `schema_migrations.sql` | 执行记录表 DDL（`migrate.sh` 自动执行，建表） |
| `V00N__*.sql` | 增量迁移（禁止修改已发布文件） |
| `V001__tx_order_sharding.sql` | 订单分表基础：主键去自增 + 分片映射表 + 订单日汇总表（2026-10-04） |
| `V002__sub_orders_logs_global_id.sql` | 子订单/订单日志主键去自增：四张订单表主键统一为应用生成的全局唯一 ID（2026-10-04） |
| `V003__sp_search_logs.sql` | 新增搜索词日志表 `sp_search_logs`：C 端搜索埋点，供热词/零结果词统计（2026-11-19） |
| `README.md` | 本说明 |

> ⚠️ PostgreSQL 侧镜像**待补**：`pgsql/` 目前没有 `sp_search_logs`（与 `tx_*` 分表的 PG 镜像缺口同类）。
> 该表在 PG 侧若要落分区（按 `created_at` RANGE，同 `sp_inventory_logs`），需同步改 `pgsql/03_partitions.sql`。

## 用法

```bash
# 对当前基线库（run.sh 建出 / 手工对齐到当前 schema）执行：自动登记 baseline → 无待执行
bash sql/migrate.sh

# 预览将登记/将执行的内容（不写库）
bash sql/migrate.sh --dry-run

# 指定目标库
DB_NAME=my_db bash sql/migrate.sh
```

> 迁移运行器第一次对某库执行时，若该库的 `schema_migrations` 为空/不存在，会自动写入
> `version='baseline'` 记录（含义：该库已处于当前 run.sh 基线）。此后新增的 V00N 才会被应用。
> ⚠️ 若你的库是用**早于当前基线**的代码建的（schema 比当前旧），请先重建（`bash run.sh`）
> 或手工将 schema 对齐到当前基线，再使用 migrate.sh——历史回放脚本已废弃，不再提供。
