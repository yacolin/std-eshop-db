#!/usr/bin/env python3
"""
种子：部门中心 — 部门 / 员工-部门关联
"""
from seed_common import *


def seed_departments(conn):
    with conn.cursor() as cur:
        DEPARTMENTS = [
            (1,  "研发中心",  0, 1),
            (2,  "运营部",    0, 2),
            (3,  "财务部",    0, 3),
            (4,  "客服部",    0, 4),
            (5,  "仓储物流部", 0, 5),
            (6,  "人事行政部", 0, 6),
            (7,  "市场部",    0, 7),
            (8,  "前端组",    1, 1),
            (9,  "后端组",    1, 2),
            (10, "测试组",    1, 3),
            (11, "内容运营组", 2, 1),
            (12, "商家运营组", 2, 2),
            (13, "数据分析组", 2, 3),
        ]

        for dept_id, name, parent_id, sort_order in DEPARTMENTS:
            cur.execute(
                "INSERT IGNORE INTO sys_departments (id, name, parent_id, sort_order, status) "
                "VALUES (%s, %s, %s, %s, 1)",
                (dept_id, name, parent_id, sort_order),
            )

        STAFF_DEPT = {
            'admin':     [(1, 1), (2, 1)],
            'colin':     [(2, 1)],
            'op_user':   [(11, 1)],
            'editor':    [(11, 1)],
            'wh_user':   [(5, 1)],
            'fin_user':  [(3, 1)],
            'mch_user':  [(12, 1)],
            'spt_user':  [(4, 1)],
            'aly_user':  [(13, 1)],
        }

        assigned = 0
        for username, depts in STAFF_DEPT.items():
            cur.execute("SELECT id FROM sys_staff WHERE username = %s AND deleted_at IS NULL", (username,))
            staff_row = cur.fetchone()
            if not staff_row:
                continue
            staff_id = staff_row[0]
            for dept_id, is_primary in depts:
                cur.execute(
                    "INSERT IGNORE INTO sys_staff_departments (staff_id, department_id, is_primary) "
                    "VALUES (%s, %s, %s)",
                    (staff_id, dept_id, is_primary),
                )
                assigned += 1

    conn.commit()
    print(f"  部门: {len(DEPARTMENTS)}, 员工-部门: {assigned} 条")
    print("部门中心 ✅\n")
