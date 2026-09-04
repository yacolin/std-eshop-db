# Seed 数据治理（P2）

> 依据 `SCHEMA_ROADMAP.md` §4 事项⑦“Seed 数据治理与测试/生产数据隔离”交付。

## 1. 分层

| 层 | 内容 | 是否进生产 | 入口 |
| --- | --- | --- | --- |
| RBAC/静态基础 | `sys_permissions`(98)/`sys_roles`(9)/`sys_role_permissions`(332)/`usr_levels`(4) | 模板级（仅白名单角色） | `sql/seed/seed_rbac.sql`（run.sh 自动） |
| 演示数据 | 商品/SKU/库存/订单/支付/评论/通知模板等 | ❌ 禁止 | `python -m sql.seed.seed_test_data`（MySQL）/ `python3 -m pgsql.seed.seed_test_data --clean`（PG） |

## 2. 固定 seed 的版本与清理顺序

- `seed_data.py`（双库各一份）是**纯数据字典**（常量），被各域模块引用；不在业务模块里硬编码大字典。
- 清理顺序 = 依赖倒序：`sql/seed/seed_clean.py`（`clean()`）TRUNCATE 的列表必须覆盖 `seed_test_data.py` 生成的**全部**表，且顺序与建表依赖无关（TRUNCATE 无外键依赖，本库无 FK）。
- 若 seed 脚本写入了新表，必须同步补 `seed_clean.py` 表清单，否则 `--clean` 后残留脏数据掩盖问题。
- 验证：`--clean` 后重新生成，各表计数与 `seed_test_data.py` 尾部的统计块一致；重复执行 `--clean` 全量必须幂等（同一 DB 两次 `--clean` 结果一致）。

## 3. 可重复执行与幂等约定（重要）

- **seed 是非幂等的追加生成器**：重复执行不 `--clean` 会重复插入并撞唯一键
  （例如 `usr_levels.uk_level`）。正确姿势：
  - 首次/空库：`python -m sql.seed.seed_test_data`
  - 已有数据重生成：**必须先 `--clean`**（TRUNCATE 全部业务表）
  - 只跑单个域：`--module product` 等（同样需 `--clean` 后再跑，避免依赖旧数据）
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

- 计数校验：`seed_test_data.py` 尾部自动打印各表行数（可 grep 断言）。
- 结构校验：`tests/test_sql_schema.py`（双库）保证 seed 脚本引用的列与 DDL 一致。

## 6. 验收

- [x] 分层与入口约定（文档 + 入口注释）。
- [x] 清理顺序表覆盖所有演示表（`seed_clean.py` 与实际生成表一致，P0/P1 已核对）。
- [x] 双库 seed 通过 `--clean` 全量验证。
- [ ] 生产部署拦截策略（部署工具层，待工程环境）。
