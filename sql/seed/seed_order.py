#!/usr/bin/env python3
"""
种子：订单中心 — 订单 / 子订单 / 订单项 / 订单日志 / 支付 / 退款

本文件是订单分表改造（sql/migrations/V001、V002）之后重写的**规范数据**生成器：
数据形状对齐 gf-eshop 应用层与 sql/P0_状态机契约.md，而不是旧版的「能插入就行」。

规范要点
--------
1. 主键：tx_orders / tx_sub_orders / tx_order_items / tx_order_logs 已去掉
   AUTO_INCREMENT，主键由应用按「分钟(25)|秒(6)|序列(20)」（51 位，< 2^53）生成。
   本脚本用 encode_order_id() 复刻同一布局并**显式写入主键** —— 不写就报 Error 1364。
2. 分片：四张表同键同片，分片键是订单 created_at 的月份（tx_orders_202608）。
   写入目标由 order_shard_mode() 自动探测：主表 / 月分片 / 双写。
3. 单一时间基准：一个 order_time 同时派生 order_no、主键时间位与分片后缀，三者必然同月。
4. 单号：ORD / SUB + YYYYMMDDHHMMSS(14) + 每秒序列(6)，与 identity.go buildOrderNo 一致；
   支付单 PAY、退款单 RFD 同规则。
5. 状态机：按 P0_状态机契约生成，paid_at / shipped_at / delivered_at / completed_at /
   closed_at 与 status 严格对应，且时间轴单调；每次状态迁移都写 tx_order_logs。
6. 金额：pay_amount = total - discount + shipping；父订单按商家拆子订单，
   折扣按金额比例分摊，Σ子单金额 == 父单金额（含运费只落一个子单）。
7. 引用：tx_order_items.merchant_id == 子订单 merchant_id；退款单金额 == 支付单金额。

注意
----
seed 仍是**追加式生成器**：重复执行前必须 `--clean`（TRUNCATE 全部演示表）。
`tx_order_shard_map` 只服务迁移前的旧自增主键；新数据可按 ID 反解分片，故本脚本不写该表。

与旧脚本的差异（除上述规范化外）
--------------------------------
* 旧脚本每人一单一个子订单、且子订单商家取「第一个明细的商家」，会出现
  `tx_order_items.merchant_id != tx_sub_orders.merchant_id` 的自相矛盾数据；
  现按商家拆子订单，并以「部分发货」强制跨商家来覆盖多子单场景。
* 旧脚本的收货地址从省/市/区三个列表各自随机取，会生成「广东省·杭州市」；
  现改用自洽的三元组。
* 旧脚本 `source` 会写入词表外的 `mobile`，现统一为 pc/app/miniapp/h5。
* **移除了跨域副作用**：旧脚本在建单时扣减 `sp_inventories` 并写 `sp_inventory_logs`。
  库存属库存域（`seed_inventory`），订单域种子越权改库存会让「只跑 order 模块」
  重复执行时库存持续漂移；订单驱动的扣减是**应用运行期**行为，不是种子数据。
  如需恢复这段联动，在 `--clean` 全量重生成的前提下可加回。
"""
from .seed_common import *

#: 生成订单数 / 覆盖最近天数（跨月，用于验证分片路由）。可用环境变量覆盖。
ORDER_COUNT = int(os.getenv("ORDER_SEED_COUNT", "2000"))
DAYS_BACK = int(os.getenv("ORDER_SEED_DAYS", "90"))
MAX_ITEMS_PER_ORDER = 4
MAX_QTY_PER_ITEM = 3

#: 省 / 市 / 区三元组必须自洽（旧脚本从三个列表各随机取一个，会出现「广东省·杭州市」）。
CITIES = [
    ("广东省", "广州市", "天河区"),
    ("广东省", "深圳市", "南山区"),
    ("浙江省", "杭州市", "西湖区"),
    ("浙江省", "宁波市", "鄞州区"),
    ("北京市", "北京市", "海淀区"),
    ("上海市", "上海市", "浦东新区"),
    ("四川省", "成都市", "高新区"),
    ("江苏省", "南京市", "鼓楼区"),
]

#: 父订单状态计划：(status, payment_status, weight)，覆盖契约里的全部状态。
PARENT_STATUS_PLAN = [
    ("pending",         "unpaid",    1),
    ("cancelled",       "unpaid",    1),
    ("closed",          "unpaid",    1),
    ("paid",            "paid",      3),
    ("partial_shipped", "paid",      2),
    ("completed",       "paid",      4),
    ("refunding",       "refunding", 1),
    ("refunded",        "refunded",  1),
]
PARENT_STATUSES = [s for s, _, _ in PARENT_STATUS_PLAN]
PARENT_WEIGHTS = [w for _, _, w in PARENT_STATUS_PLAN]
PARENT_PAYMENT_STATUS = {s: ps for s, ps, _ in PARENT_STATUS_PLAN}

#: 已发生支付的状态（这些状态才有支付单、paid_at）。
PAID_STATUSES = {"paid", "partial_shipped", "completed", "refunding", "refunded"}
#: 进入退款链路的状态。
REFUND_STATUSES = {"refunding", "refunded"}

PAYMENT_METHODS = ["alipay", "wechat", "alipay", "wechat", "wallet"]
CHANNEL_OF = {"wechat": "wechat_native", "alipay": "alipay_page", "wallet": "wallet"}
TRADE_PREFIX = {"wechat": "4200", "alipay": "2026", "wallet": "9000"}
SOURCE_CHOICES = ["pc", "app", "pc", "pc", "miniapp", "h5"]
REFUND_REASONS = ["七天无理由退货", "商品与描述不符", "质量问题", "拍错/多拍", "未按约定时间发货"]


def _pick_skus(skus, weights, count):
    """按权重不放回抽样：同一订单内不出现重复 SKU（旧脚本允许重复）。"""
    chosen, seen = [], set()
    for _ in range(count * 30):
        if len(chosen) >= count:
            break
        sku = random.choices(skus, weights=weights, k=1)[0]
        if sku[0] in seen:
            continue
        seen.add(sku[0])
        chosen.append(sku)
    return chosen


def _allocate_discount(total_discount, group_totals):
    """
    把父订单折扣按各组金额比例分摊到子订单。

    两条硬约束：分摊额不得超过该组商品金额（否则子单 pay_amount 为负，撞 CHECK）；
    分摊额之和必须等于父订单折扣（否则 Σ子单金额 != 父单金额）。
    """
    alloc = {m: 0 for m in group_totals}
    grand = sum(group_totals.values())
    if total_discount <= 0 or grand <= 0:
        return alloc
    total_discount = min(total_discount, grand)
    assigned = 0
    for m, amount in group_totals.items():
        share = min(total_discount * amount // grand, amount)
        alloc[m] = share
        assigned += share
    rest = total_discount - assigned
    for m in sorted(group_totals, key=lambda x: -group_totals[x]):
        if rest <= 0:
            break
        room = group_totals[m] - alloc[m]
        add = min(room, rest)
        alloc[m] += add
        rest -= add
    return alloc


def _sub_plan(parent_status, merchant_ids):
    """返回 [(merchant_id, 子单状态, 退款状态)]，与父订单状态严格对应。"""
    if parent_status in ("pending", "cancelled", "closed"):
        return [(m, parent_status, "none") for m in merchant_ids]
    if parent_status == "paid":
        return [(m, "paid", "none") for m in merchant_ids]
    if parent_status == "partial_shipped":
        # 至少一个子单未发货，「部分发货」才在数据上成立（生成时已强制 >=2 个商家）
        shipped = max(1, len(merchant_ids) - 1)
        return [(m, "shipped" if i < shipped else "paid", "none")
                for i, m in enumerate(merchant_ids)]
    if parent_status == "completed":
        # 契约：父单 completed = 全部子单 delivered（子单不再单独置 completed）
        return [(m, "delivered", "none") for m in merchant_ids]
    if parent_status == "refunding":
        return [(m, "refunding", "refunding") for m in merchant_ids]
    return [(m, "refunded", "refunded") for m in merchant_ids]


def _timeline(parent_status, created_at):
    """按父订单状态生成严格单调的时间轴（未发生的里程碑一律 NULL）。"""
    t = {"paid_at": None, "shipped_at": None, "delivered_at": None,
         "completed_at": None, "closed_at": None}
    if parent_status in PAID_STATUSES:
        t["paid_at"] = created_at + timedelta(minutes=random.randint(1, 60))
    if parent_status in ("partial_shipped", "completed"):
        t["shipped_at"] = t["paid_at"] + timedelta(hours=random.randint(2, 48))
    if parent_status == "completed":
        t["delivered_at"] = t["shipped_at"] + timedelta(hours=random.randint(24, 120))
        t["completed_at"] = t["delivered_at"] + timedelta(hours=random.randint(1, 72))
    if parent_status in ("cancelled", "closed"):
        t["closed_at"] = created_at + timedelta(hours=random.randint(1, 24))
    return t


def _order_logs(parent_status, created_at, timeline, refund_applied_at, refund_success_at):
    """每次状态迁移追加一条订单日志（契约 §6.2），顺序与时间轴一致。"""
    logs = [("", "pending", "创建订单", "system", "system", created_at)]
    if parent_status in PAID_STATUSES:
        logs.append(("pending", "paid", "支付成功", "system", "system", timeline["paid_at"]))
    if parent_status == "partial_shipped":
        logs.append(("paid", "partial_shipped", "部分子订单已发货", "system", "system",
                     timeline["shipped_at"]))
    if parent_status == "completed":
        logs.append(("paid", "completed", "全部子订单已签收", "system", "system",
                     timeline["completed_at"]))
    if parent_status == "cancelled":
        logs.append(("pending", "cancelled", "用户取消订单", "user", "user",
                     timeline["closed_at"]))
    if parent_status == "closed":
        logs.append(("pending", "closed", "超时未支付，系统关单", "system", "system",
                     timeline["closed_at"]))
    if parent_status == "refunding":
        logs.append(("paid", "refunding", "用户发起退款申请", "user", "user", refund_applied_at))
    if parent_status == "refunded":
        logs.append(("paid", "refunding", "用户发起退款申请", "user", "user", refund_applied_at))
        logs.append(("refunding", "refunded", "退款成功", "system", "system", refund_success_at))
    return logs


def seed_order(conn):
    now = datetime.now().replace(microsecond=0)
    order_alloc = OrderSeqAllocator("订单")
    pay_alloc = OrderSeqAllocator("支付单")
    refund_alloc = OrderSeqAllocator("退款单")

    with conn.cursor() as cur:
        mode = order_shard_mode(cur)
        if mode == "none":
            print("  ⚠ 订单域无任何物理表（主表与月分片都不存在），请先执行 bash run.sh")
            return
        print(f"  订单分片布局: { {'single': '主表(未分表)', 'monthly': '月分片', 'dual': '主表+分片双写'}[mode] }")

        if mode != "single":
            months = sorted({(now - timedelta(days=d)).strftime("%Y%m")
                             for d in range(DAYS_BACK + 1)})
            for month in months:
                ensure_order_shard_tables(cur, month)
            print(f"  分片表就绪: {', '.join(months)}")
        ensured_months = set(months) if mode != "single" else set()

        # ── 基础数据（沿用原脚本：用户不足时补 test_user_*）────────────────
        cur.execute("SELECT id FROM mch_merchants WHERE deleted_at IS NULL ORDER BY id")
        merchant_ids = [row[0] for row in cur.fetchall()] or [0]

        cur.execute("""
            SELECT s.id, s.product_id, s.sku_code, s.price, s.spec_summary, p.name, p.main_image, p.merchant_id
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
                cur.execute(
                    "INSERT IGNORE INTO usr_users (username, password_hash, nickname, phone, email, status, register_source) "
                    "VALUES (%s, %s, %s, %s, %s, 1, 'pc')",
                    (username, f"hash_{i}", nickname, f"1{i:09d}", f"user{i}@test.com"),
                )
                if cur.lastrowid:
                    cur.execute("INSERT IGNORE INTO usr_infos (user_id) VALUES (%s)", (cur.lastrowid,))
                    existing_ids.add(cur.lastrowid)
            conn.commit()
            cur.execute("SELECT id FROM usr_users WHERE deleted_at IS NULL")
            users = cur.fetchall()
        if not users:
            print("  ⚠ 无用户数据，跳过订单生成")
            return

        # 用户促销（历史包袱：一直放在订单模块里，迁移到 seed_marketing 前保持行为不变）
        cur.execute("SELECT id, promo_type FROM mkt_promotions")
        for promo_id, promo_type in cur.fetchall():
            if promo_type == 3:
                continue
            recipients = random.sample(users, min(len(users), max(1, int(len(users) * random.uniform(0.3, 0.8)))))
            for u in recipients:
                cur.execute(
                    "INSERT IGNORE INTO mkt_user_promotions (user_promotion_no, user_id, promotion_id, expire_time, status) "
                    "VALUES (%s, %s, %s, %s, 1)",
                    (f"UPROMO{u[0]}-{promo_id}", u[0], promo_id,
                     (now + timedelta(days=random.randint(7, 60))).strftime(FMT)),
                )

        # ── 逐单生成 ──────────────────────────────────────────────────────
        status_counts = {}
        total_subs = total_items = total_logs = total_payments = total_refunds = 0

        for _ in range(ORDER_COUNT):
            # 单一时间基准：order_time 同时决定单号、主键时间位与分片后缀
            order_time = now - timedelta(
                days=random.randint(0, DAYS_BACK),
                hours=random.randint(0, 23),
                minutes=random.randint(0, 59),
                seconds=random.randint(0, 59),
            )
            parent_status = random.choices(PARENT_STATUSES, weights=PARENT_WEIGHTS)[0]
            payment_status = PARENT_PAYMENT_STATUS[parent_status]
            user_id = random.choice(users)[0]

            # 兜底：万一 order_time 落到了预热范围之外的月份，先确保该月分片存在
            if mode != "single":
                month = order_time.strftime("%Y%m")
                if month not in ensured_months:
                    ensure_order_shard_tables(cur, month)
                    ensured_months.add(month)

            # 明细：不放回抽样；「部分发货」强制跨商家，否则拆不出多个子订单
            order_skus = _pick_skus(skus, sku_weights, random.randint(1, MAX_ITEMS_PER_ORDER))
            if parent_status == "partial_shipped":
                picked = {s[7] for s in order_skus}
                if len(picked) < 2:
                    pool = [s for s in skus if s[7] not in picked]
                    if pool:
                        order_skus.append(random.choice(pool))
            if not order_skus:
                continue

            items = []
            for sku in order_skus:
                price = int(sku[3])
                qty = random.randint(1, MAX_QTY_PER_ITEM)
                items.append({
                    "sku_id": sku[0], "product_id": sku[1], "sku_code": sku[2],
                    "price": price, "qty": qty, "subtotal": price * qty,
                    "product_name": sku[5], "image": sku[6], "spec": sku[4],
                    "merchant_id": sku[7],
                })

            total_amount = sum(i["subtotal"] for i in items)
            shipping_fee = random.choice([0, 0, 0, 800, 1200])
            discount = min(random.randint(0, int(total_amount * 0.1)), total_amount)
            pay_amount = total_amount + shipping_fee - discount

            # 按商家拆子订单；折扣按金额分摊、运费只落首个子单，保证父/子金额求和一致
            groups = {}
            for it in items:
                groups.setdefault(it["merchant_id"], []).append(it)
            group_merchants = list(groups.keys())
            group_totals = {m: sum(i["subtotal"] for i in g) for m, g in groups.items()}
            discount_alloc = _allocate_discount(discount, group_totals)
            shipping_alloc = {m: 0 for m in group_merchants}
            shipping_alloc[group_merchants[0]] = shipping_fee
            sub_plan = _sub_plan(parent_status, group_merchants)

            timeline = _timeline(parent_status, order_time)
            refund_applied_at = refund_success_at = None
            if parent_status in REFUND_STATUSES:
                refund_applied_at = timeline["paid_at"] + timedelta(hours=random.randint(2, 72))
                if parent_status == "refunded":
                    refund_success_at = refund_applied_at + timedelta(hours=random.randint(1, 48))
            logs = _order_logs(parent_status, order_time, timeline,
                               refund_applied_at, refund_success_at)

            milestones = [order_time] + [
                timeline[k] for k in ("paid_at", "shipped_at", "delivered_at",
                                      "completed_at", "closed_at") if timeline[k]
            ]
            milestones += [v for v in (refund_applied_at, refund_success_at) if v]
            order_updated_at = max(milestones)

            # 一个订单一次分配连续序列：订单 → 子订单 → 明细 → 日志
            need = 1 + len(group_merchants) + len(items) + len(logs)
            start = order_alloc.allocate(order_time, need)
            order_id = encode_order_id(order_time, start)
            order_no = build_business_no("ORD", order_time, start)

            sub_ids, sub_nos = {}, {}
            cursor_seq = start + 1
            for merchant_id in group_merchants:
                sub_ids[merchant_id] = encode_order_id(order_time, cursor_seq)
                sub_nos[merchant_id] = build_business_no("SUB", order_time, cursor_seq)
                cursor_seq += 1
            item_ids = [encode_order_id(order_time, cursor_seq + i) for i in range(len(items))]
            cursor_seq += len(items)
            log_ids = [encode_order_id(order_time, cursor_seq + i) for i in range(len(logs))]

            province, city, district = random.choice(CITIES)
            payment_method = random.choice(PAYMENT_METHODS) if parent_status in PAID_STATUSES else ""
            insert_sharded(cur, mode, "tx_orders", order_time, (
                "id", "order_no", "user_id", "total_amount", "discount_amount", "shipping_fee",
                "pay_amount", "status", "payment_status", "payment_method", "consignee", "phone",
                "province", "city", "district", "detail_addr", "zip_code", "source",
                "paid_at", "shipped_at", "delivered_at", "completed_at", "closed_at",
                "created_at", "updated_at",
            ), (
                order_id, order_no, user_id, total_amount, discount, shipping_fee,
                pay_amount, parent_status, payment_status, payment_method,
                f"用户{user_id}", f"138{random.randint(10000000, 99999999)}",
                province, city, district,
                f"{random.randint(100, 999)}号{random.choice(['小区', '大厦', '路'])}{random.randint(1, 99)}栋",
                f"{random.randint(100000, 999999)}",
                random.choice(SOURCE_CHOICES),
                timeline["paid_at"], timeline["shipped_at"], timeline["delivered_at"],
                timeline["completed_at"], timeline["closed_at"],
                order_time, order_updated_at,
            ))

            for merchant_id, sub_status, refund_status in sub_plan:
                sub_paid = timeline["paid_at"] if parent_status in PAID_STATUSES else None
                sub_shipped = timeline["shipped_at"] if sub_status in ("shipped", "delivered") else None
                sub_delivered = timeline["delivered_at"] if sub_status == "delivered" else None
                sub_closed = timeline["closed_at"] if sub_status in ("cancelled", "closed") else None
                sub_updated = max([v for v in (sub_paid, sub_shipped, sub_delivered, sub_closed)
                                   if v] + [order_time])
                insert_sharded(cur, mode, "tx_sub_orders", order_time, (
                    "id", "sub_order_no", "parent_order_id", "parent_order_no", "user_id", "merchant_id",
                    "total_amount", "discount_amount", "shipping_fee", "pay_amount",
                    "status", "refund_status", "seller_remark",
                    "paid_at", "shipped_at", "delivered_at", "completed_at", "closed_at",
                    "created_at", "updated_at",
                ), (
                    sub_ids[merchant_id], sub_nos[merchant_id], order_id, order_no, user_id, merchant_id,
                    group_totals[merchant_id], discount_alloc[merchant_id], shipping_alloc[merchant_id],
                    group_totals[merchant_id] - discount_alloc[merchant_id] + shipping_alloc[merchant_id],
                    sub_status, refund_status, "",
                    sub_paid, sub_shipped, sub_delivered, None, sub_closed,
                    order_time, sub_updated,
                ))
                total_subs += 1

            for idx, it in enumerate(items):
                if parent_status == "refunded":
                    item_refund_status, item_refund_amount = "refunded", it["subtotal"]
                    item_updated = refund_success_at
                elif parent_status == "refunding":
                    item_refund_status, item_refund_amount = "refunding", 0
                    item_updated = refund_applied_at
                else:
                    item_refund_status, item_refund_amount = "none", 0
                    item_updated = order_time
                insert_sharded(cur, mode, "tx_order_items", order_time, (
                    "id", "order_id", "sub_order_id", "merchant_id", "order_no", "sub_order_no",
                    "sku_id", "product_id", "sku_code", "product_name", "sku_spec_summary", "image",
                    "price", "quantity", "subtotal", "refund_status", "refund_amount",
                    "created_at", "updated_at",
                ), (
                    item_ids[idx], order_id, sub_ids[it["merchant_id"]], it["merchant_id"], order_no,
                    sub_nos[it["merchant_id"]], it["sku_id"], it["product_id"], it["sku_code"],
                    it["product_name"],
                    it["spec"] if it["spec"] and it["spec"] != "{}" else None,
                    it["image"], it["price"], it["qty"], it["subtotal"],
                    item_refund_status, item_refund_amount,
                    order_time, item_updated,
                ))
                total_items += 1

            for idx, (from_status, to_status, note, operator, operator_type, log_time) in enumerate(logs):
                insert_sharded(cur, mode, "tx_order_logs", order_time, (
                    "id", "order_id", "order_no", "from_status", "to_status",
                    "operator", "operator_type", "note", "created_at",
                ), (
                    log_ids[idx], order_id, order_no, from_status, to_status,
                    operator, operator_type, note, log_time,
                ))
                total_logs += 1

            # ── 支付 / 退款（tx_payments、tx_refunds 不分片，只写一份）────────
            if parent_status in PAID_STATUSES:
                pay_moment = max(order_time, timeline["paid_at"] - timedelta(seconds=random.randint(30, 600)))
                pay_seq = pay_alloc.allocate(pay_moment, 1)
                payment_no = build_business_no("PAY", pay_moment, pay_seq)
                channel = CHANNEL_OF[payment_method]
                transaction_id = f"{TRADE_PREFIX[payment_method]}{pay_moment.strftime(ORDER_NO_TIME_FMT)}{pay_seq:06d}"
                pay_status = {"refunding": "refunding", "refunded": "refunded"}.get(parent_status, "paid")
                if parent_status == "refunding":
                    pay_updated = refund_applied_at
                elif parent_status == "refunded":
                    pay_updated = refund_success_at
                else:
                    pay_updated = timeline["paid_at"]
                cur.execute(
                    """INSERT INTO tx_payments (payment_no, order_no, order_id, merchant_id, order_type,
                       amount, currency, payment_method, channel, trade_type, transaction_id, idempotency_key,
                       status, failure_reason, client_ip, expire_at, paid_at, notify_at, channel_response,
                       created_at, updated_at)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                    (payment_no, order_no, order_id, group_merchants[0], "order",
                     pay_amount, "CNY", payment_method, channel, "native", transaction_id, payment_no,
                     pay_status, "", "127.0.0.1",
                     timeline["paid_at"] + timedelta(minutes=30), timeline["paid_at"], timeline["paid_at"],
                     json.dumps({"trade_state": "SUCCESS", "out_trade_no": payment_no}, ensure_ascii=False),
                     pay_moment, pay_updated),
                )
                payment_id = cur.lastrowid
                total_payments += 1

                log_rows = [
                    (payment_id, payment_no, channel, transaction_id, "create", "unpaid", pay_moment),
                    (payment_id, payment_no, channel, transaction_id, "pay", "paid", timeline["paid_at"]),
                ]
                if parent_status in REFUND_STATUSES:
                    log_rows.append((payment_id, payment_no, channel, transaction_id,
                                     "refund", "refunding", refund_applied_at))
                if parent_status == "refunded":
                    log_rows.append((payment_id, payment_no, channel, transaction_id,
                                     "refund_callback", "refunded", refund_success_at))
                for pid, pno, ch, txid, action, st, created in log_rows:
                    cur.execute(
                        """INSERT INTO tx_payment_logs (payment_id, payment_no, channel, transaction_id,
                           action, request_body, response_body, status, created_at)
                           VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                        (pid, pno, ch, txid, action,
                         json.dumps({"out_trade_no": pno, "action": action}, ensure_ascii=False),
                         json.dumps({"status": st}, ensure_ascii=False),
                         st, created),
                    )

                if parent_status in REFUND_STATUSES:
                    refund_seq = refund_alloc.allocate(refund_applied_at, 1)
                    refund_no = build_business_no("RFD", refund_applied_at, refund_seq)
                    refund_status = "processing" if parent_status == "refunding" else "success"
                    channel_refund_id = (
                        None if refund_status == "processing"
                        else f"RF{refund_applied_at.strftime(ORDER_NO_TIME_FMT)}{refund_seq:06d}"
                    )
                    cur.execute(
                        """INSERT INTO tx_refunds (refund_no, payment_id, payment_no, order_no, order_id,
                           merchant_id, amount, reason, status, channel_refund_id, failure_reason,
                           channel_response, idempotency_key, applied_at, success_at, notify_at,
                           created_at, updated_at)
                           VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                        (refund_no, payment_id, payment_no, order_no, order_id,
                         group_merchants[0], pay_amount, random.choice(REFUND_REASONS),
                         refund_status, channel_refund_id, "",
                         json.dumps({"refund_status": "SUCCESS"}, ensure_ascii=False)
                         if refund_status == "success" else None,
                         refund_no, refund_applied_at, refund_success_at, refund_success_at,
                         refund_applied_at, refund_success_at or refund_applied_at),
                    )
                    total_refunds += 1

            status_counts[parent_status] = status_counts.get(parent_status, 0) + 1

    conn.commit()
    print(f"  订单: {ORDER_COUNT}（跨 {DAYS_BACK} 天）, 子订单: {total_subs}, "
          f"订单项: {total_items}, 订单日志: {total_logs}")
    print(f"  支付: {total_payments}, 退款: {total_refunds}")
    print("  状态分布: " + ", ".join(f"{k}={v}" for k, v in sorted(status_counts.items())))
    print("订单中心 ✅\n")
