#!/usr/bin/env python3
"""
verify_order_seed.py — 订单域「规范数据」校验（分表 + 雪花主键）

用法（仓库根目录，需一个已 seed 过的库）：
    python3 tools/verify_order_seed.py
    python3 tools/verify_order_seed.py --verbose
    DB_NAME=eshop_db python3 tools/verify_order_seed.py

校验口径见 sql/P2_Seed治理.md §5：
  1. 主键：全部 id 是「分钟(25)|秒(6)|序列(20)」编码（> 2^40），反解出的时间 == created_at，
     月份与所在月分片一致，序列位非 0；
  2. 单号：order_no == ORD + created_at(14 位) + ID 序列位(6 位)；sub_order_no 前缀 SUB；
  3. 状态机：status 与 payment_status、paid_at/shipped_at/delivered_at/completed_at/closed_at
     严格对应且时间轴单调；
  4. 金额：Σ子单四项金额 == 父单、Σ明细 subtotal == 父单 total、明细商家 == 子单商家；
  5. 日志：每单至少一条，首条 '' → pending，末条 to_status == status，相邻首尾相接；
  6. 支付/退款：支付金额 == 订单实付、退款金额 == 支付金额；tx_order_shard_map 为空；
  7. 全局：跨分片 id / order_no / sub_order_no 唯一，legacy 副本为空。

退出码：0 = 通过；1 = 有违规；2 = 无法连接 / 无订单分片。
"""
import argparse
import pathlib
import sys
from collections import defaultdict
from datetime import timedelta

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sql.seed.seed_common import (  # noqa: E402
    connect, table_exists, list_tables_like, active_order_tables, active_order_suffixes,
    order_shard_mode, physical_table, ORDER_SHARD_BASES, ORDER_ID_EPOCH, ORDER_ID_SEQ_MASK,
    ORDER_ID_SECOND_BITS, ORDER_ID_SEQ_BITS, LEGACY_ORDER_ID_MAX,
)

PAID = {"paid", "partial_shipped", "completed", "refunding", "refunded"}
PAY_MAP = {"pending": "unpaid", "cancelled": "unpaid", "closed": "unpaid",
           "paid": "paid", "partial_shipped": "paid", "completed": "paid",
           "refunding": "refunding", "refunded": "refunded"}
MILESTONES = ("paid_at", "shipped_at", "delivered_at", "completed_at", "closed_at")


def fetch(cur, table):
    """整表读回为 dict 列表（列名 → 值）。"""
    cur.execute(f"SELECT * FROM `{table}`")
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, row)) for row in cur.fetchall()]


def decode_order_id(oid):
    """复刻 identity.go decodeOrderID，返回本地时间与序列。"""
    seq = oid & ORDER_ID_SEQ_MASK
    second = (oid >> ORDER_ID_SEQ_BITS) & ((1 << ORDER_ID_SECOND_BITS) - 1)
    minutes = oid >> (ORDER_ID_SECOND_BITS + ORDER_ID_SEQ_BITS)
    moment = (ORDER_ID_EPOCH + timedelta(minutes=minutes, seconds=second)) \
        .astimezone().replace(tzinfo=None)
    return moment, seq


def main():
    parser = argparse.ArgumentParser(description="校验订单域规范数据")
    parser.add_argument("--verbose", action="store_true", help="打印每个分片的行数")
    args = parser.parse_args()

    conn = connect()
    cur = conn.cursor()
    mode = order_shard_mode(cur)
    if mode == "none":
        print("订单域没有任何物理表：该库尚未建表或尚未 seed")
        return 2
    # 活跃表：monthly/dual 只取月分片（主表是镜像），single 取主表
    suffixes = active_order_suffixes(cur)

    problems = []

    def check(ok, msg):
        if not ok:
            problems.append(msg)

    orders, subs, items, logs = {}, {}, {}, {}
    for suf in suffixes:
        for base, bucket in (("tx_orders", orders), ("tx_sub_orders", subs),
                             ("tx_order_items", items), ("tx_order_logs", logs)):
            table = physical_table(base, suf)
            check(table_exists(cur, table), f"缺表 {table}")
            if table_exists(cur, table):
                bucket[suf] = fetch(cur, table)

    # 1~2. 主键编码 / 单号 / 分片
    for suf, rows in orders.items():
        if args.verbose:
            print(f"  分片 {suf}: orders={len(rows)} subs={len(subs.get(suf, []))} "
                  f"items={len(items.get(suf, []))} logs={len(logs.get(suf, []))}")
        for o in rows:
            oid = o["id"]
            moment, seq = decode_order_id(oid)
            check(o["created_at"].strftime("%Y%m") == suf,
                  f"{o['order_no']} created_at 不在分片 {suf}")
            check(oid > LEGACY_ORDER_ID_MAX, f"{o['order_no']} 主键仍是 legacy 量级: {oid}")
            check(seq > 0, f"{o['order_no']} 序列位为 0（decodeOrderID 判为非法）")
            check(moment == o["created_at"],
                  f"{o['order_no']} 主键时间 {moment} != created_at {o['created_at']}")
            check(o["order_no"] == f"ORD{moment.strftime('%Y%m%d%H%M%S')}{seq:06d}",
                  f"{o['order_no']} 与主键时间/序列不一致")
            check(o["pay_amount"] == o["total_amount"] - o["discount_amount"] + o["shipping_fee"],
                  f"{o['order_no']} pay != total - discount + shipping")

    # 3. 状态机 / 时间轴
    for rows in orders.values():
        for o in rows:
            st = o["status"]
            check(o["payment_status"] == PAY_MAP.get(st),
                  f"{o['order_no']} payment_status={o['payment_status']} 与 status={st} 不符")
            check((o["paid_at"] is not None) == (st in PAID),
                  f"{o['order_no']} status={st} 与 paid_at 不符")
            check((o["shipped_at"] is not None) == (st in ("partial_shipped", "completed")),
                  f"{o['order_no']} status={st} 与 shipped_at 不符")
            check((o["delivered_at"] is not None) == (st == "completed"),
                  f"{o['order_no']} status={st} 与 delivered_at 不符")
            check((o["completed_at"] is not None) == (st == "completed"),
                  f"{o['order_no']} status={st} 与 completed_at 不符")
            check((o["closed_at"] is not None) == (st in ("cancelled", "closed")),
                  f"{o['order_no']} status={st} 与 closed_at 不符")
            chain = [o["created_at"]] + [o[f] for f in MILESTONES if o[f]]
            check(all(chain[i] <= chain[i + 1] for i in range(len(chain) - 1)),
                  f"{o['order_no']} 时间轴非单调: {chain}")

    # 4. 金额守恒 / 商家一致 / 引用完整性
    subs_by_order, items_by_order = defaultdict(list), defaultdict(list)
    for rows in subs.values():
        for s in rows:
            subs_by_order[s["parent_order_id"]].append(s)
    for rows in items.values():
        for it in rows:
            items_by_order[it["order_id"]].append(it)

    for rows in orders.values():
        for o in rows:
            ss, its = subs_by_order[o["id"]], items_by_order[o["id"]]
            check(len(ss) >= 1, f"{o['order_no']} 没有子订单")
            if not ss or not its:
                continue
            for field in ("total_amount", "discount_amount", "shipping_fee", "pay_amount"):
                check(sum(s[field] for s in ss) == o[field],
                      f"{o['order_no']} Σ子单 {field} != 父单")
            check(sum(i["subtotal"] for i in its) == o["total_amount"],
                  f"{o['order_no']} Σ明细 subtotal != 父单 total")
            sub_ids = {s["id"] for s in ss}
            by_id = {s["id"]: s for s in ss}
            sub_statuses = {s["status"] for s in ss}
            for s in ss:
                check(s["parent_order_no"] == o["order_no"] and s["parent_order_id"] == o["id"],
                      f"子单 {s['sub_order_no']} 父单引用不一致")
                check(s["sub_order_no"].startswith("SUB"),
                      f"子单号前缀异常 {s['sub_order_no']}")
            for it in its:
                check(it["sub_order_id"] in sub_ids,
                      f"明细 {it['id']} 指向不存在的子单")
                check(it["order_no"] == o["order_no"], f"明细 {it['id']} 订单号不一致")
                check(it["subtotal"] == it["price"] * it["quantity"],
                      f"明细 {it['id']} subtotal != price*quantity")
                if it["sub_order_id"] in by_id:
                    check(it["merchant_id"] == by_id[it["sub_order_id"]]["merchant_id"],
                          f"明细 {it['id']} 商家 != 子单商家")
            if o["status"] == "partial_shipped":
                check(len(ss) >= 2 and "shipped" in sub_statuses and "paid" in sub_statuses,
                      f"{o['order_no']} partial_shipped 数据不成立: {sub_statuses}")
            if o["status"] == "completed":
                check(sub_statuses == {"delivered"},
                      f"{o['order_no']} completed 子单状态 {sub_statuses}")
            if o["status"] == "refunded":
                check(sub_statuses == {"refunded"},
                      f"{o['order_no']} refunded 子单状态 {sub_statuses}")

    # 5. 订单日志覆盖与链路闭合
    logs_by_order = defaultdict(list)
    for rows in logs.values():
        for lg in rows:
            logs_by_order[lg["order_id"]].append(lg)
    for rows in orders.values():
        for o in rows:
            ls = sorted(logs_by_order[o["id"]], key=lambda x: (x["created_at"], x["id"]))
            check(len(ls) >= 1, f"{o['order_no']} 没有订单日志")
            if not ls:
                continue
            check(ls[0]["from_status"] == "" and ls[0]["to_status"] == "pending",
                  f"{o['order_no']} 首条日志不是创建")
            check(ls[-1]["to_status"] == o["status"],
                  f"{o['order_no']} 末条日志 {ls[-1]['to_status']} != status {o['status']}")
            for a, b in zip(ls, ls[1:]):
                check(a["to_status"] == b["from_status"],
                      f"{o['order_no']} 日志链断裂 {a['to_status']} -> {b['from_status']}")

    # 6. 支付 / 退款 / 辅助表
    payments = fetch(cur, "tx_payments")
    refunds = fetch(cur, "tx_refunds")
    cur.execute("SELECT COUNT(*) FROM tx_payment_logs")
    pay_logs = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM tx_order_shard_map")
    shard_map = cur.fetchone()[0]

    all_orders = {o["id"]: o for rows in orders.values() for o in rows}
    pay_by_id = {p["id"]: p for p in payments}
    for p in payments:
        check(p["order_id"] in all_orders, f"支付 {p['payment_no']} 指向不存在的订单")
        check(p["amount"] > 0, f"支付 {p['payment_no']} 金额非正")
        check(p["status"] in ("paid", "refunding", "refunded"),
              f"支付 {p['payment_no']} 状态异常 {p['status']}")
        if p["order_id"] in all_orders:
            o = all_orders[p["order_id"]]
            check(p["order_no"] == o["order_no"] and p["amount"] == o["pay_amount"],
                  f"支付 {p['payment_no']} 金额/单号与订单不符")
    for r in refunds:
        check(r["payment_id"] in pay_by_id, f"退款 {r['refund_no']} 指向不存在的支付单")
        if r["payment_id"] in pay_by_id:
            check(r["amount"] == pay_by_id[r["payment_id"]]["amount"],
                  f"退款 {r['refund_no']} 金额 != 支付金额")
        check(r["status"] in ("processing", "success"), f"退款状态异常 {r['status']}")
        if r["status"] == "success":
            check(r["channel_refund_id"] and r["success_at"], "成功退款缺渠道号/成功时间")
        else:
            check(r["channel_refund_id"] is None and r["success_at"] is None,
                  "进行中退款不应有渠道号/成功时间")
    check(shard_map == 0, f"tx_order_shard_map 应为空，实际 {shard_map} 行")
    check(pay_logs >= len(payments), f"支付日志 {pay_logs} 少于支付单 {len(payments)}")

    # 7. 跨分片唯一性 / legacy 副本
    #    业务单号只有 tx_orders.order_no 与 tx_sub_orders.sub_order_no 是唯一键；
    #    tx_order_items / tx_order_logs 的 order_no 是冗余列（一个订单多行），不做唯一断言。
    #    dual（主表 + 分片并存）下只校验活跃分片：主表是同一批行的镜像，一起算会误报重复。
    for base in ORDER_SHARD_BASES:
        id_key = {"tx_orders": "order_no", "tx_sub_orders": "sub_order_no"}.get(base)
        ids, nos = [], []
        for name in active_order_tables(cur, base):
            rows = fetch(cur, name)
            ids += [r["id"] for r in rows]
            if id_key:
                nos += [r[id_key] for r in rows]
        check(len(ids) == len(set(ids)), f"{base} 跨分片存在重复 id")
        if id_key:
            check(len(nos) == len(set(nos)), f"{base}.{id_key} 跨分片存在重复")

        # legacy 归档副本：留着也必须是空的（且不应再与基线争用 CHECK 约束名）
        for name in list_tables_like(cur, base):
            if "_legacy_" not in name:
                continue
            cur.execute(f"SELECT COUNT(*) FROM `{name}`")
            n = cur.fetchone()[0]
            check(n == 0, f"legacy 副本 {name} 残留 {n} 行")

    conn.close()

    label = ", ".join(s if s else "主表" for s in suffixes)
    print(f"布局: {mode}（校验活跃表: {label}）")
    print(f"订单={len(all_orders)} 支付={len(payments)} 退款={len(refunds)} 支付日志={pay_logs}")
    if problems:
        print(f"\n❌ 发现 {len(problems)} 个问题（最多显示 40 条）：")
        for p in problems[:40]:
            print("  -", p)
        return 1
    print("\n✅ 订单规范数据校验通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
