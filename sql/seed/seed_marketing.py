#!/usr/bin/env python3
"""
种子：营销中心 — 促销 / 规则 / 产品关联
"""
from seed_common import *


def seed_marketing(conn):
    now = datetime.now()
    now_str = now.strftime(FMT)

    promos = [
        ("满200减30", 4, 20000, 3000, 1, 1000),
        ("满500减100", 4, 50000, 10000, 1, 500),
        ("满1000减200", 4, 100000, 20000, 1, 300),
        ("全场8折", 5, 0, 20, 0, 0),
        ("全场85折", 5, 0, 15, 0, 0),
        ("新用户满减券", 1, 0, 5000, 1, 500),
        ("新用户专属8折", 1, 0, 20, 1, 300),
        ("会员9折", 6, 0, 10, 0, 0),
        ("会员85折", 6, 0, 15, 0, 0),
        ("限时秒杀-手机", 3, 0, 50, 1, 50),
        ("限时秒杀-耳机", 3, 0, 30, 2, 100),
        ("限时秒杀-运动鞋", 3, 0, 40, 1, 80),
        ("限时秒杀-化妆品", 3, 0, 25, 2, 120),
        ("双11预售", 2, 0, 0, 1, 1000),
        ("618大促", 2, 0, 0, 1, 1000),
        ("品牌日特惠", 2, 0, 0, 1, 500),
        ("圣诞限定折扣", 2, 0, 0, 1, 300),
    ]

    with conn.cursor() as cur:
        cur.execute("SELECT id FROM mch_merchants WHERE deleted_at IS NULL ORDER BY id")
        merchant_ids = [row[0] for row in cur.fetchall()] or [0]

        for i, (name, ptype, condition, benefit, per_limit, total_qty) in enumerate(promos, 1):
            start = (now - timedelta(days=random.randint(0, 5))).strftime(FMT)
            end = (now + timedelta(days=random.randint(3, 30))).strftime(FMT)
            status = random.choices([1, 2, 3], weights=[1, 8, 1])[0]
            merchant_id = random.choice(merchant_ids)

            promo_no = f"PROMO{i:04d}"
            cur.execute(
                "INSERT INTO mkt_promotions (promotion_no, merchant_id, promo_name, promo_type, promo_code, start_time, end_time, "
                "total_quantity, per_user_limit, used_quantity, status, priority, created_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (promo_no, merchant_id, name, ptype, f"CODE{i:04d}", start, end,
                 total_qty, per_limit, random.randint(0, int(total_qty * 0.5)), status, 0, now_str),
            )
            promo_id = cur.lastrowid

            benefit_config = json.dumps({"type": 1 if ptype in [4, 5, 6, 7, 8] else 2, "value": benefit})
            rule_condition = 2 if condition > 0 else 1
            cur.execute(
                "INSERT INTO mkt_promotion_rules (promotion_id, merchant_id, rule_name, condition_type, condition_value, "
                "benefit_config, is_stackable, stack_group, created_at) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (promo_id, merchant_id, f"{name}规则", rule_condition, condition,
                 benefit_config, 1, 0, now_str),
            )
            rule_id = cur.lastrowid
            cur.execute("UPDATE mkt_promotions SET rule_id = %s WHERE id = %s", (rule_id, promo_id))

            if ptype == 3:
                cur.execute("SELECT id FROM sp_products ORDER BY RAND() LIMIT %s", (random.randint(3, 8),))
                for p in cur.fetchall():
                    cur.execute(
                        "INSERT INTO mkt_promotion_products (promotion_id, merchant_id, product_type, target_id, created_at) "
                        "VALUES (%s, %s, 3, %s, %s)", (promo_id, merchant_id, p[0], now_str),
                    )

    conn.commit()
    print("营销中心 ✅\n")
