#!/usr/bin/env python3
"""
种子：积分中心 — 积分流水 / 积分规则 / 等级升降级规则
"""
from seed_common import *


def seed_points(conn):
    now = datetime.now()

    with conn.cursor() as cur:
        cur.execute("SELECT id FROM usr_users WHERE deleted_at IS NULL")
        users = [u[0] for u in cur.fetchall()]
        if not users:
            print("  ⚠ 无用户数据，跳过积分生成")
            return

        cur.execute(
            "SELECT id, user_id, pay_amount, created_at FROM tx_orders "
            "WHERE status IN ('paid','completed') AND deleted_at IS NULL"
        )
        orders = cur.fetchall()
        user_orders = {u: [] for u in users}
        for oid, ouid, amount, otime in orders:
            if ouid in user_orders:
                user_orders[ouid].append((oid, amount, otime))

        total_records = 0

        for user_id in users:
            balance = 0
            records = []

            # 1. 签到积分
            for day_offset in range(30):
                if random.random() < 0.4:
                    day = (now - timedelta(days=day_offset)).strftime(FMT)
                    points = 5
                    balance += points
                    records.append({
                        "user_id": user_id, "points": points,
                        "balance_after": balance,
                        "source": "signin", "source_id": "",
                        "status": 1, "remark": "每日签到奖励",
                        "created_at": day,
                    })

            # 2. 订单消费积分
            for oid, amount, otime in user_orders.get(user_id, []):
                points = int(amount)
                if points <= 0:
                    continue
                balance += points
                records.append({
                    "user_id": user_id, "points": points,
                    "balance_after": balance,
                    "source": "order", "source_id": str(oid),
                    "status": 1, "remark": f"订单消费{amount}积分奖励",
                    "created_at": otime.strftime(FMT) if hasattr(otime, "strftime") else str(otime),
                })

            # 3. 评价奖励
            for oid, amount, otime in user_orders.get(user_id, []):
                if random.random() < 0.3:
                    points = 20
                    balance += points
                    review_time = otime + timedelta(days=1)
                    records.append({
                        "user_id": user_id, "points": points,
                        "balance_after": balance,
                        "source": "review", "source_id": str(oid),
                        "status": 1, "remark": "评价奖励积分",
                        "created_at": review_time.strftime(FMT) if hasattr(review_time, "strftime") else str(review_time),
                    })

            # 4. 管理员调整
            if user_id == 1 and random.random() < 0.5:
                adj_points = random.choice([100, 200, 300, 500])
                balance += adj_points
                records.append({
                    "user_id": user_id, "points": adj_points,
                    "balance_after": balance,
                    "source": "admin", "source_id": "",
                    "status": 1, "remark": "管理员手动调整积分",
                    "created_at": (now - timedelta(days=random.randint(1, 10))).strftime(FMT),
                })

            # 5. 过期积分
            active_records = [r for r in records if r["source"] != "expire"]
            if active_records and len(active_records) > 5 and random.random() < 0.3:
                expire_amount = random.randint(50, 200)
                last_balance = records[-1]["balance_after"]
                records.append({
                    "user_id": user_id, "points": -expire_amount,
                    "balance_after": last_balance - expire_amount,
                    "source": "expire", "source_id": "",
                    "status": 2, "remark": "积分过期清零",
                    "created_at": (now - timedelta(days=random.randint(0, 3))).strftime(FMT),
                })

            if not records:
                continue

            records.sort(key=lambda r: r["created_at"])
            for r in records:
                cur.execute(
                    "INSERT INTO usr_points "
                    "(user_id, points, balance_after, source, source_id, status, remark, created_at) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                    (r["user_id"], r["points"], r["balance_after"],
                     r["source"], r["source_id"], r["status"], r["remark"], r["created_at"]),
                )
                total_records += 1

    conn.commit()
    print(f"  积分流水: {total_records} 条")
    print("积分中心 ✅\n")


def seed_points_rules(conn):
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE usr_points_rules")
        for rule in POINTS_RULES:
            cur.execute(
                "INSERT INTO usr_points_rules (name, rule_key, value_int, value_decimal, value_string, description, sort_order, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                (rule["name"], rule["rule_key"],
                 rule.get("value_int"), rule.get("value_decimal"), rule.get("value_string", ""),
                 rule["description"], rule["sort_order"], rule["status"]),
            )
    conn.commit()
    print(f"  积分规则: {len(POINTS_RULES)} 条")
    print("积分规则 ✅\n")


def seed_level_rules(conn):
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE usr_level_rules")
        for rule in LEVEL_RULES:
            cur.execute(
                "INSERT INTO usr_level_rules (name, rule_type, from_level_id, to_level_id, "
                "condition_type, condition_value, description, sort_order, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (rule["name"], rule["rule_type"], rule["from_level_id"], rule["to_level_id"],
                 rule["condition_type"], rule["condition_value"], rule["description"],
                 rule["sort_order"], rule["status"]),
            )
    conn.commit()
    print(f"  等级升降级规则: {len(LEVEL_RULES)} 条")
    print("等级升降级规则 ✅\n")
