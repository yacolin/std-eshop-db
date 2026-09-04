# Schema Diff 使用说明（P2）

> 依据 `SCHEMA_ROADMAP.md` §4 事项③“Schema diff”交付。
> 运行器：`tools/schema_diff.py`（Python 3 静态解析，不连库；git 仓库内使用）

## 用法

```bash
# 工作区（未提交）相对 HEAD 的 schema 变化
python3 tools/schema_diff.py

# 相对某 commit / 标签
python3 tools/schema_diff.py --base 7a2d5e0

# 单引擎
python3 tools/schema_diff.py --engine mysql
python3 tools/schema_diff.py --engine pg
```

## 输出内容

对 sql/（MySQL）与 pgsql/（PostgreSQL）各自报告：

| 标记 | 含义 | 是否破坏性 |
| --- | --- | --- |
| `+ 表/列/索引/CHECK` | 新增 | 否（列新增默认可回滚窗口） |
| `~ 列定义变化` | 类型/默认值/注释变化 | 视具体变更（类型收窄 = 破坏性） |
| `- 列 删除列` | 删除列 | **DESTRUCTIVE**（数据丢失风险） |
| `- 索引/唯一键移除` | 索引或约束移除 | 通常安全，需确认无重复索引依赖 |
| `- CHECK 移除` | 约束放宽 | 安全但需评审 |

## 与 Migration 体系配合

- 每次合并 schema 变更前：先跑 `sql_lint.py`（0 违规），再跑 `schema_diff.py --base <上次迁移基线>`
  生成精确变更清单；
- 变更清单应能逐行对应到新迁移文件 `V00N`；
- 出现 `DESTRUCTIVE` 必须人工评审 + migration 文件头标注 `-- DESTRUCTIVE`，
  禁止无迁移文件直接改基线。

## 验收

- [x] 可输出表/列/索引/约束精确变化（工作区 vs HEAD 已验证）。
- [x] 破坏性变更（删列）显式标记。
- [x] 支持 git ref 对比（`--base 7a2d5e0` 可重放 P0/P1 全量差异，125 处变化）。
- [ ] 接入 CI（仓库暂无 CI 配置，属工程环境范畴）。
