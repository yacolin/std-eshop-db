# SQL Lint 规范（P2）

> 依据 `SCHEMA_ROADMAP.md` §4 事项②“SQL lint”交付。
> 运行器：`tools/sql_lint.py`（Python 3，无第三方依赖），CI / pre-commit 可复用。
> 用法：`python3 tools/sql_lint.py`（默认检查 sql/ 与 pgsql/ 双库全量 DDL）

---

## 1. 检查规则（R1–R7 + P1 约束）

| 规则 | 检查内容 | 违规示例 → 正确做法 |
| --- | --- | --- |
| R1 | 全库禁止 `FOREIGN KEY` / `REFERENCES` | `FOREIGN KEY(user_id) REFERENCES usr_users(id)` → 删除，逻辑外键由应用保证 |
| R2 | 金额列 `bigint` 分、`NOT NULL`、表内存在引用该列的非负/正数 `CHECK` | `price DECIMAL(10,2)` → `bigint` + `CHECK (price >= 0)` |
| R3 | CHECK 约束名唯一（MySQL 要求库内唯一） | 两张表同名 `chk_amount` → 按表前缀命名 |
| R4 | 同表内禁止重复索引列集合 | `KEY idx_a(a,b)` + `KEY idx_b(a,b)` → 删冗余 |
| R5 | 常规建表文件禁止 `DROP TABLE`/`TRUNCATE` | 建表文件里 DROP → 只允许出现在 `00_drop_tables.sql` |
| R6 | 状态/枚举列必须有取值注释（MySQL `COMMENT`） | `status tinyint DEFAULT 1` → 加 `COMMENT '1-启用 0-禁用'` |
| R7 | 空串默认值禁止直接进 UNIQUE 键 | `code VARCHAR(50) DEFAULT ''` + UNIQUE → `DEFAULT NULL` 或生成列归一 `code_uq` |
| P1 | 资金表禁止 `deleted_at`（只可追加） | 资金表带软删列 → 移除，状态流转表达 |

## 2. 运行与接入

```bash
python3 tools/sql_lint.py                # 双库
python3 tools/sql_lint.py --engine mysql # 只查 MySQL
python3 tools/sql_lint.py --engine pg    # 只查 PG
echo $?                                  # 0=通过 1=违规
```

CI / Git hook 建议：在 schema 相关 PR 上运行并阻塞（`exit 1` 即失败）；
配合 `SCHEMA_ROADMAP.md` §4 的 schema diff 一起组成“迁移审查”门槛。

## 3. 注意事项

- 工具面向**静态基线 DDL**（`sql/*.sql`、`pgsql/*.sql`），不解析迁移目录（迁移正确性由回放演练保证）。
- 若某条规则与业务冲突（例如确有负金额冲正表），在 `MONEY_COLS`/规则例外清单登记并写注释，禁止静默关规则。
- 新状态值、新金额列必须在提交中同时补 COMMENT 与 CHECK，否则 lint 会拦截。
- 破坏性迁移（`DROP COLUMN`/`ALTER TYPE`）必须在 migration 文件头标 `-- DESTRUCTIVE` 并人工评审。

## 4. 验收

- [x] 规则实现并双库跑通（当前 0 违规）。
- [x] 可在 CI / pre-commit 接入（纯 Python，无依赖）。
- [ ] 接入真实 CI（仓库当前无 CI 配置文件，属工程环境范畴）。
