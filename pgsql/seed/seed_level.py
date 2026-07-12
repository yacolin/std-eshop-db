#!/usr/bin/env python3
"""
种子：用户中心 等级
"""
from seed_common import *


def seed_level(conn):
    now = datetime.now()
    now_str = now.strftime(FMT)

    with conn.cursor() as cur:
        for level_data in USER_LEVEL:
            cur.execute(
                "INSERT INTO usr_levels (name, level, min_points, discount_rate, "
                "free_shipping, points_multiplier, benefits, status, sort_order, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) "
                "ON CONFLICT (level) DO NOTHING",
                (
                    level_data['name'],
                    level_data['level'],
                    level_data['min_points'],
                    level_data['discount_rate'],
                    level_data['free_shipping'],
                    level_data['points_multiplier'],
                    json.dumps(level_data['benefits'], ensure_ascii=False),
                    level_data['status'],
                    level_data['sort_order'],
                    now_str,
                    now_str,
                )
            )
    conn.commit()
    print(f"  用户等级: {len(USER_LEVEL)} 条")
    print("用户等级 ✅\n")
