#!/bin/bash
# ============================================================
# sql/migrate.sh — MySQL 版本化迁移运行器（以当前 schema 为基线）
#
# 用法（仓库根目录执行）：
#   bash sql/migrate.sh                      # 应用到默认库 eshop_db
#   DB_NAME=my_db bash sql/migrate.sh        # 指定目标库
#   bash sql/migrate.sh --dry-run            # 仅预览，不写库
#
# 基线模型：
#   - 当前仓库 sql/*.sql（run.sh 建出的 73 表 schema）即 BASELINE
#   - 首次对某库执行时：若 schema_migrations 为空/不存在 → 自动登记 version='baseline'
#   - baseline 之后的增量迁移：sql/migrations/V00N__*.sql（当前为空，未来新增）
#
# 约定：新库/当前基线库跑本脚本 = 登记 baseline、无待执行；早于当前基线的旧库不提供回放，
#       请先用 run.sh 重建或手工对齐到当前基线。
# ============================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGR_DIR="${ROOT_DIR}/sql/migrations"
DB_NAME="${DB_NAME:-eshop_db}"
MYSQL_USER="${MYSQL_USER:-root}"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

mysql_exec() { MYSQL_PWD="${MYSQL_PWD:-}" mysql -u "${MYSQL_USER}" "${DB_NAME}" "$@"; }

BASELINE_DESC="当前 run.sh 基线（73 表 schema，含 P0-P2 治理成果）"

# 1) 确保执行记录表存在（dry-run 不建表）
if [ "$DRY_RUN" -eq 0 ]; then
  mysql_exec < "${MIGR_DIR}/schema_migrations.sql"
fi

applied=$(mysql_exec -N -e "SELECT version FROM schema_migrations;" 2>/dev/null || true)

# 2) 首次登记 baseline：记录表存在但无任何版本 → 写入 baseline（表示该库 == 当前基线）
if [ "$DRY_RUN" -eq 0 ] && [ -z "$applied" ]; then
  mysql_exec -e "INSERT INTO schema_migrations (version, file_name, description, applied_by)
                 VALUES ('baseline', 'BASELINE', '${BASELINE_DESC}', '${USER:-system}');"
  echo "已登记 baseline（库 ${DB_NAME} == 当前 run.sh 基线）"
  applied="baseline"
elif [ "$DRY_RUN" -eq 1 ] && [ -z "$applied" ]; then
  echo "(dry-run) 将登记 baseline（库 ${DB_NAME} == 当前 run.sh 基线）"
fi

# 3) 收集待执行迁移（baseline 之后的增量）
pending=()
for f in "${MIGR_DIR}"/V*.sql; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  ver="${base%%__*}"
  if ! echo "$applied" | grep -qx "$ver"; then
    pending+=("$f")
  fi
done

if [ "${#pending[@]}" -eq 0 ]; then
  echo "schema_migrations: 无待执行迁移（库 ${DB_NAME} 已是最新基线）"
  exit 0
fi

echo "待执行迁移 (${#pending[@]}):"
for f in "${pending[@]}"; do echo "  - $(basename "$f")"; done

[ "$DRY_RUN" -eq 1 ] && { echo "(dry-run 结束，未执行)"; exit 0; }

# 4) 逐个执行并记录
for f in "${pending[@]}"; do
  base="$(basename "$f")"
  ver="${base%%__*}"
  desc="$(sed -n 's/^--[[:space:]]*//p' "$f" | head -1)"
  echo "==> 执行 ${base}"
  start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
  mysql_exec < "$f"
  end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
  exec_ms=$((end_ms - start_ms))
  checksum=$(shasum -a 256 "$f" | awk '{print $1}')
  mysql_exec -e "INSERT INTO schema_migrations (version, file_name, description, checksum, applied_by, execution_ms)
                 VALUES ('${ver}', '${base}', '${desc}', '${checksum}', '${USER:-system}', ${exec_ms});"
done

echo "迁移完成：库 ${DB_NAME} 共应用 ${#pending[@]} 个迁移"
