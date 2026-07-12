#!/usr/bin/env python3
"""
种子：订单中心 — 订单 / 子订单 / 订单项 / 支付 / 退款 / 用户促销
"""
from seed_common import *


def _insert_get_id(cur, sql, params):
    cur.execute(sql + " RETURNING id", params)
    row = cur.fetchone()
    return row[0] if row else None


def seed_order(conn):
    now = datetime.now()

    with conn.cursor() as cur:
        cur.execute("SELECT id FROM mch_merchants WHERE deleted_at IS NULL ORDER BY id")
        merchant_ids = [row[0] for row in cur.fetchall()] or [0]

        cur.execute("""
            SELECT s.id, s.product_id, s.sku_code, s.price, s.spec, p.name, p.main_image, p.merchant_id
            FROM sp_skus s JOIN sp_products p ON p.id = s.product_id
            WHERE s.deleted_at IS NULL AND p.deleted_at IS NULL
        """)
        skus = cur.fetchall()
        if not skus:
            print("  ⚠ 无 SKU 数据，跳过订单生成")
            return
        sku_weights = [max(1, 100 - i * 0.4) for i in range(len(skus))]

        cur.execute("SELECT id FROM usr_users WHERE deleted_at IS NULL")
        users = cur.fetchall()
        if len(users) < 20:
            existing_ids = {u[0] for u in users}
            for i in range(1, 51):
                if i in existing_ids:
                    continue
                username = f"test_user_{i}"
                nickname = f"{random.choice(['小明','小红','张三','李四','王五','赵六','测试','游客'])}{i}"
                uid = _insert_get_id(cur, """
                    INSERT INTO usr_users (username, password_hash, nickname, phone, email, status, register_source)
                    VALUES (%s, %s, %s, %s, %s, 1, 'pc')
                    ON CONFLICT DO NOTHING
                """, (username, f"hash_{i}", nickname, f"1{i:09d}", f"user{i}@test.com"))
                if uid:
                    cur.execute("INSERT INTO usr_infos (user_id) VALUES (%s)", (uid,))
                    existing_ids.add(uid)
            conn.commit()
            cur.execute("SELECT id FROM usr_users WHERE deleted_at IS NULL")
            users = cur.fetchall()

        cur.execute("SELECT id, promo_type FROM mkt_promotions")
        for promo_id, promo_type in cur.fetchall():
            if promo_type == 3:
                continue
            recipients = random.sample(users, min(len(users), max(1, int(len(users) * random.uniform(0.3, 0.8)))))
            for u in recipients:
                expire = now + timedelta(days=random.randint(7, 60))
                cur.execute(
                    "INSERT INTO mkt_user_promotions (user_promotion_no, user_id, promotion_id, expire_time, status) "
                    "VALUES (%s, %s, %s, %s, 1) ON CONFLICT DO NOTHING",
                    (f"UPROMO{u[0]}-{promo_id}", u[0], promo_id, expire.strftime(FMT)),
                )

        total_orders = 0
        total_items = 0
        total_payments = 0

        for _ in range(2000):
            order_date = now - timedelta(
                days=random.randint(0, 30), hours=random.randint(0, 23), minutes=random.randint(0, 59),
            )
            order_no = f"ORD{order_date.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
            user_id = random.choice(users)[0]
            parent_status = random.choices(PARENT_ORDER_STATUSES, weights=PARENT_ORDER_STATUS_WEIGHTS)[0]
            sub_status = SUB_ORDER_STATUS_MAP[parent_status]

            item_count = random.randint(1, 4)
            order_skus = random.choices(skus, weights=sku_weights, k=item_count)
            total_amount = 0
            order_items = []

            for sku in order_skus:
                sku_id, prod_id, sku_code, price, spec, prod_name, image, sku_merchant_id = sku
                spec_summary = " / ".join(str(v) for v in (spec or {}).values()) if isinstance(spec, dict) else ""
                qty = random.randint(1, 3)
                subtotal = price * qty
                total_amount += subtotal
                order_items.append((sku_id, prod_id, sku_code, price, qty, subtotal, prod_name, image, spec_summary, sku_merchant_id))

            shipping_fee = random.choice([0, 0, 0, 800, 1200])
            discount = random.randint(0, int(total_amount * 0.1))
            pay_amount = total_amount + shipping_fee - discount
            if pay_amount <= 0:
                pay_amount = total_amount

            payment_status = "paid" if parent_status in ("paid", "completed") \
                else "unpaid" if parent_status == "pending" \
                else "refunded"

            consignee = f"用户{user_id}"
            phone = f"138{random.randint(10000000, 99999999)}"

            order_merchant_id = order_items[0][9] if order_items else random.choice(merchant_ids)

            order_id = _insert_get_id(cur, """
                INSERT INTO tx_orders (order_no, user_id, total_amount, discount_amount, shipping_fee,
                pay_amount, status, payment_status, consignee, phone,
                province, city, district, detail_addr, source, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (order_no, user_id, total_amount, discount, shipping_fee,
                  pay_amount, parent_status, payment_status,
                  consignee, phone,
                  random.choice(["广东省", "浙江省", "北京市", "上海市", "四川省"]),
                  random.choice(["广州市", "杭州市", "海淀区", "浦东新区", "成都市"]),
                  random.choice(["天河区", "西湖区", "中关村", "陆家嘴", "高新区"]),
                  f"{random.randint(100,999)}号{random.choice(['小区','大厦','路'])}{random.randint(1,99)}栋",
                  random.choice(["pc", "mobile", "pc", "pc"]),
                  order_date.strftime(FMT), order_date.strftime(FMT)))

            sub_order_no = f"SO{order_date.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
            sub_total = total_amount
            sub_shipping = shipping_fee
            sub_discount = discount
            sub_pay = pay_amount

            time_fields = {}
            if parent_status in ("paid", "completed"):
                time_fields["paid_at"] = (order_date + timedelta(minutes=random.randint(1, 60))).strftime(FMT)
            if sub_status in ("shipped", "delivered"):
                time_fields["shipped_at"] = (order_date + timedelta(hours=random.randint(2, 48))).strftime(FMT)
            if sub_status == "delivered":
                time_fields["delivered_at"] = (order_date + timedelta(hours=random.randint(48, 120))).strftime(FMT)
            if parent_status == "completed":
                time_fields["completed_at"] = (order_date + timedelta(days=random.randint(3, 7))).strftime(FMT)
            if parent_status == "cancelled":
                time_fields["closed_at"] = (order_date + timedelta(hours=random.randint(1, 24))).strftime(FMT)

            sub_order_id = _insert_get_id(cur, """
                INSERT INTO tx_sub_orders (sub_order_no, parent_order_id, parent_order_no, user_id, merchant_id,
                total_amount, discount_amount, shipping_fee, pay_amount, status,
                paid_at, shipped_at, delivered_at, completed_at, closed_at,
                created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s, %s)
            """, (sub_order_no, order_id, order_no, user_id, order_merchant_id,
                  sub_total, sub_discount, sub_shipping, sub_pay, sub_status,
                  time_fields.get("paid_at"), time_fields.get("shipped_at"),
                  time_fields.get("delivered_at"), time_fields.get("completed_at"),
                  time_fields.get("closed_at"),
                  order_date.strftime(FMT), order_date.strftime(FMT)))

            for item in order_items:
                sku_id, prod_id, sku_code, price, qty, subtotal, prod_name, image, spec_summary, sku_merchant_id = item
                cur.execute(
                    """INSERT INTO tx_order_items (order_id, sub_order_id, merchant_id, order_no, sub_order_no,
                       sku_id, product_id, sku_code, product_name, sku_spec_summary, image,
                       price, quantity, subtotal, created_at, updated_at)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                    (order_id, sub_order_id, sku_merchant_id, order_no, sub_order_no,
                     sku_id, prod_id, sku_code, prod_name,
                     spec_summary if spec_summary else None, image,
                     price, qty, subtotal,
                     order_date.strftime(FMT), order_date.strftime(FMT)),
                )
                total_items += 1

                if parent_status not in ("cancelled", "pending"):
                    cur.execute(
                        "SELECT quantity, reserved FROM sp_inventories WHERE sku_id = %s FOR UPDATE",
                        (sku_id,),
                    )
                    inv = cur.fetchone()
                    if inv:
                        before_qty, before_reserved = int(inv[0]), int(inv[1])
                        after_qty = max(0, before_qty - qty)
                        after_reserved = max(0, before_reserved - qty)
                        cur.execute(
                            "UPDATE sp_inventories SET quantity = %s, reserved = %s, status = %s WHERE sku_id = %s",
                            (after_qty, after_reserved,
                             3 if after_qty <= 0 else 2 if after_qty < 10 else 1, sku_id),
                        )
                        cur.execute(
                            """INSERT INTO sp_inventory_logs (sku_id, merchant_id, change_type, before_quantity, after_quantity,
                               before_reserved, after_reserved, change_amount, reference_id, operator, note)
                               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                             (sku_id, sku_merchant_id, "order", before_qty, after_qty,
                              before_reserved, after_reserved, -qty, f"{order_no}_{sku_id}_{random.randint(100,999)}", "system", "订单扣减"),
                        )

            if parent_status in ("paid", "completed", "refunded"):
                paid_at = order_date + timedelta(minutes=random.randint(1, 60))
                payment_no = f"PAY{paid_at.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
                payment_method = random.choice(["alipay", "wechat", "alipay", "wechat", "wallet"])
                idempotency_key = f"PAY_{order_no}_{order_id}"
                payment_id = _insert_get_id(cur, """
                    INSERT INTO tx_payments (payment_no, order_no, order_id, merchant_id, amount, payment_method,
                    channel, trade_type, idempotency_key, status, paid_at, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (payment_no, order_no, order_id, order_merchant_id, pay_amount, payment_method,
                      payment_method, "native", idempotency_key,
                      "success" if parent_status != "refunded" else "refunded",
                      paid_at.strftime(FMT), order_date.strftime(FMT), paid_at.strftime(FMT)))
                total_payments += 1

                # 物流单：已发货/已签收订单
                if parent_status in ("paid", "completed") and random.random() < 0.7:
                    carriers = ["sf", "yto", "zto", "yunda", "jd"]
                    carrier = random.choice(carriers)
                    tracking_no = f"{random.choice(['SF','YT','ZT','YD','JD'])}{random.randint(1000000000, 9999999999)}"
                    delivery_no = f"DEL{order_date.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"

                    deli_status = "delivered" if parent_status == "completed" else "shipped"
                    shipped_at = order_date + timedelta(hours=random.randint(2, 48))
                    delivered_at = (shipped_at + timedelta(days=random.randint(1, 5))) if parent_status == "completed" else None

                    delivery_id = _insert_get_id(cur, """
                        INSERT INTO tx_deliveries
                        (delivery_no, order_id, order_no, merchant_id, carrier, tracking_no, warehouse_id,
                         consignee, phone, province, city, district, detail_addr, shipping_fee,
                         status, shipped_at, delivered_at, created_by)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (delivery_no, order_id, order_no, order_merchant_id, carrier, tracking_no, 1,
                          consignee, phone,
                          random.choice(["广东省", "浙江省", "北京市", "上海市"]),
                          random.choice(["广州市", "杭州市", "海淀区", "浦东新区"]),
                          random.choice(["天河区", "西湖区", "中关村", "陆家嘴"]),
                          f"{random.randint(100,999)}号{random.choice(['小区','大厦'])}{random.randint(1,99)}栋",
                          shipping_fee, deli_status,
                          shipped_at.strftime(FMT), delivered_at.strftime(FMT) if delivered_at else None, 1))

                    # 物流明细（查该订单的 order_item_id）
                    cur.execute(
                        "SELECT id, sku_id FROM tx_order_items WHERE order_id = %s",
                        (order_id,),
                    )
                    for oi_id, oi_sku_id in cur.fetchall():
                        cur.execute(
                            "INSERT INTO tx_delivery_items (delivery_id, order_item_id, sku_id, quantity) "
                            "VALUES (%s, %s, %s, 1)",
                            (delivery_id, oi_id, oi_sku_id),
                        )

                    # 物流轨迹
                    trace_entries = [
                        (shipped_at - timedelta(hours=random.randint(1, 4)),
                         f"{random.choice(['深圳','广州','上海','北京'])}分拣中心", "已揽收",
                         "快件已被揽收"),
                        (shipped_at,
                         f"{random.choice(['深圳','广州','上海','北京'])}转运中心", "运输中",
                         "快件已从始发地发出"),
                    ]
                    if parent_status == "completed":
                        trace_entries.append(
                            (delivered_at,
                             f"{random.choice(['深圳','广州','上海'])}{random.choice(['天河','福田','浦东'])}",
                             "已签收", "快件已被签收"),
                        )
                    for tt, loc, sts, desc in trace_entries:
                        cur.execute(
                            "INSERT INTO tx_delivery_traces (delivery_id, tracking_no, trace_time, location, status, description) "
                            "VALUES (%s, %s, %s, %s, %s, %s)",
                            (delivery_id, tracking_no, tt.strftime(FMT), loc, sts, desc),
                        )

                if parent_status == "refunded":
                    refund_no = f"RFD{paid_at.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
                    refund_idempotency_key = f"RFD_{refund_no}_{order_id}"
                    cur.execute(
                        """INSERT INTO tx_refunds (refund_no, payment_id, payment_no, order_no, order_id, merchant_id,
                           amount, reason, status, idempotency_key, applied_at, success_at, created_at, updated_at)
                           VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                        (refund_no, payment_id, payment_no, order_no, order_id, order_merchant_id,
                         pay_amount, "测试退款", "success", refund_idempotency_key,
                         (order_date + timedelta(days=1)).strftime(FMT),
                         paid_at.strftime(FMT), order_date.strftime(FMT), paid_at.strftime(FMT)),
                    )

            total_orders += 1

    conn.commit()
    print(f"  订单: {total_orders}, 订单项: {total_items}, 支付: {total_payments}")
    print("订单中心 ✅\n")
