#!/usr/bin/env python3
"""
种子：库存中心 — 仓库 / 库存 / 库存流水
"""
from seed_common import *


def _insert_get_id(cur, sql, params):
    cur.execute(sql + " RETURNING id", params)
    row = cur.fetchone()
    return row[0] if row else None


def seed_inventory(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM mch_merchants WHERE deleted_at IS NULL ORDER BY id")
        merchant_ids = [row[0] for row in cur.fetchall()] or [0]

        cur.execute("SELECT id FROM sp_warehouses LIMIT 1")
        wh = cur.fetchone()
        if not wh:
            merchant_id = random.choice(merchant_ids)
            wh_id = _insert_get_id(cur, """
                INSERT INTO sp_warehouses (merchant_id, warehouse_name, warehouse_type, status)
                VALUES (%s, %s, 1, 1)
            """, (merchant_id, "默认仓库"))
        else:
            wh_id = wh[0]

        cur.execute("SELECT id, merchant_id FROM sp_skus WHERE deleted_at IS NULL")
        skus = cur.fetchall()
        for sku_id, sku_merchant_id in skus:
            roll = random.random()
            if roll < 0.10:
                qty, reserved, threshold = 0, 0, random.randint(5, 30)
                status = 'outofstock'
            elif roll < 0.25:
                threshold = random.randint(10, 30)
                qty = random.randint(1, threshold - 1)
                reserved = random.randint(0, min(qty, 5))
                status = 'lowstock'
            else:
                qty = random.randint(50, 1000)
                reserved = random.randint(0, int(qty * 0.3))
                threshold = random.randint(5, 50)
                status = 'instock' if qty > threshold else 'lowstock'
            cur.execute(
                "INSERT INTO sp_inventories (sku_id, merchant_id, warehouse_id, quantity, reserved, threshold, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (sku_id, sku_merchant_id, wh_id, qty, reserved, threshold, status),
            )

            if random.random() < 0.3:
                delta = random.randint(10, 50)
                cur.execute(
                    "INSERT INTO sp_inventory_logs (sku_id, merchant_id, warehouse_id, before_quantity, after_quantity, "
                    "before_reserved, after_reserved, change_amount, "
                    "change_type, reference_id, operator, note) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                    (sku_id, sku_merchant_id, wh_id, qty - delta, qty, 0, reserved, delta,
                     "purchase", f"PURCHASE_{sku_id}", "admin", "初始入库"),
                )
    conn.commit()
    print(f"  库存: {len(skus)} 条")
    print("库存中心 ✅\n")
