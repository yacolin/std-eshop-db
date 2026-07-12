#!/usr/bin/env python3
"""
种子：评价中心 — 评价 / 媒体 / 回复 / 审核日志
"""
from seed_common import *


def _insert_get_id(cur, sql, params):
    cur.execute(sql + " RETURNING id", params)
    row = cur.fetchone()
    return row[0] if row else None


def seed_review(conn):
    now = datetime.now()

    with conn.cursor() as cur:
        cur.execute("""
            SELECT oi.id, oi.order_id, oi.product_id, oi.sku_id,
                   o.user_id, o.created_at, oi.merchant_id
            FROM tx_order_items oi
            JOIN tx_orders o ON o.id = oi.order_id
            WHERE o.status IN ('paid','completed') AND o.deleted_at IS NULL
              AND oi.id NOT IN (SELECT order_item_id FROM rev_reviews WHERE status != 3)
            ORDER BY o.created_at DESC
        """)
        items = cur.fetchall()
        if not items:
            print("  ⚠ 无已支付订单项，跳过评价生成")
            return

        items = list(items)
        random.shuffle(items)
        review_items = [it for it in items if random.random() < 0.5][:500]
        if not review_items:
            print("  ⚠ 无评价生成")
            return

        review_contents = {
            (5, 4): [
                "商品质量很好，做工精致，值得购买！",
                "物流很快，包装完好，好评！",
                "颜色和图片一致，非常满意。",
                "非常满意的一次购物体验！",
                "性价比很高，下次还会回购。",
                "发货速度快，客服态度也很好。",
                "用了几天才来评价，效果超出预期。",
                "质量不错，价格合理，推荐购买。",
            ],
            (3, 3): [
                "整体还不错，但细节有待改进。",
                "一般般吧，没有想象中好。",
                "中规中矩，没有惊喜。",
                "还行吧，但性价比一般。",
            ],
            (1, 2): [
                "质量太差了，完全不值这个价。",
                "很失望，和描述不符。",
                "收到就有瑕疵，体验很差。",
                "不会再买了，质量堪忧。",
            ],
        }

        total_reviews = 0
        total_media = 0
        total_replies = 0
        total_audit_logs = 0

        for item in review_items:
            item_id, order_id, spu_id, sku_id, user_id, order_time, item_merchant_id = item

            rating_weights = [1, 2, 10, 30, 57]
            overall = random.choices([1, 2, 3, 4, 5], weights=rating_weights)[0]
            quality = max(1, min(5, overall + random.randint(-1, 1)))
            logistics = max(1, min(5, overall + random.randint(-1, 1)))
            service = max(1, min(5, overall + random.randint(-1, 1)))

            if overall <= 2:
                bucket = (1, 2)
            elif overall == 3:
                bucket = (3, 3)
            else:
                bucket = (5, 4)
            content = random.choice(review_contents[bucket])
            is_anonymous = random.choice([0, 0, 0, 1])

            status = random.choices([0, 1, 2], weights=[1, 8, 1])[0]
            reject_reason = None
            if status == 2:
                reject_reason = random.choice([
                    "含不当言论", "图片与商品无关", "恶意评价",
                ])

            review_time = order_time + timedelta(days=random.randint(1, 10))

            review_no = f"RV{review_time.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
            content_length = len(content) if content else 0
            has_media = 1 if (status == 1 and random.random() < 0.3) else 0
            risk_level = 0
            review_id = _insert_get_id(cur, """
                INSERT INTO rev_reviews
                (review_no, user_id, order_id, order_item_id, spu_id, sku_id, merchant_id,
                 overall_rating, quality_rating, logistics_rating, service_rating,
                 content, content_length, is_anonymous, has_media,
                 status, risk_level, reject_reason,
                 reply_count, like_count, helpful_count,
                 created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s,
                 %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (review_no, user_id, order_id, item_id, spu_id, sku_id, item_merchant_id,
                  overall, quality, logistics, service,
                  content, content_length, is_anonymous, has_media,
                  status, risk_level, reject_reason,
                  0, random.randint(0, 20), random.randint(0, 10),
                  review_time.strftime(FMT), review_time.strftime(FMT)))
            total_reviews += 1

            cur.execute(
                "INSERT INTO rev_review_audit_logs (review_id, action, operator_id, operator_name, before_status, after_status, remark, created_at) "
                "VALUES (%s, 'submit', %s, 'user', NULL, %s, '用户提交评价', %s)",
                (review_id, user_id, status, review_time.strftime(FMT)),
            )
            total_audit_logs += 1

            if status == 1:
                cur.execute(
                    "INSERT INTO rev_review_audit_logs (review_id, action, operator_id, operator_name, before_status, after_status, remark, created_at) "
                    "VALUES (%s, 'approve', 1, 'admin', 0, 1, '审核通过', %s)",
                    (review_id, review_time.strftime(FMT)),
                )
                total_audit_logs += 1
            elif status == 2:
                cur.execute(
                    "INSERT INTO rev_review_audit_logs (review_id, action, operator_id, operator_name, before_status, after_status, remark, created_at) "
                    "VALUES (%s, 'reject', 1, 'admin', 0, 2, %s, %s)",
                    (review_id, reject_reason, review_time.strftime(FMT)),
                )
                total_audit_logs += 1

            if status == 1 and random.random() < 0.3:
                for m in range(random.randint(1, 3)):
                    cur.execute(
                        "INSERT INTO rev_review_media (review_id, media_type, media_url, file_size, width, height, sort_order, created_at) "
                        "VALUES (%s, 1, %s, %s, %s, %s, %s, %s)",
                        (review_id, f"https://cdn.eshop.dev/reviews/{review_id}/{m+1}.jpg",
                         random.randint(50000, 500000), random.randint(800, 1920), random.randint(800, 1920),
                         m, review_time.strftime(FMT)),
                    )
                    total_media += 1

            if status == 1 and random.random() < 0.2:
                reply_content = random.choice([
                    "感谢您的评价，我们会继续努力！",
                    "谢谢您的支持，欢迎再次光临！",
                    "感谢您的反馈，我们会不断改进。",
                ])
                reply_id = _insert_get_id(cur, """
                    INSERT INTO rev_review_replies (review_id, parent_id, root_reply_id, reply_type, content, operator_id, operator_name, status, created_at, updated_at)
                    VALUES (%s, NULL, NULL, 1, %s, 1, 'admin', 1, %s, %s)
                """, (review_id, reply_content, review_time.strftime(FMT), review_time.strftime(FMT)))
                total_replies += 1

                cur.execute(
                    "UPDATE rev_reviews SET reply_count = reply_count + 1 WHERE id = %s",
                    (review_id,),
                )

                if random.random() < 0.3:
                    cur.execute(
                        "INSERT INTO rev_review_replies (review_id, parent_id, root_reply_id, reply_type, content, operator_id, operator_name, status, created_at, updated_at) "
                        "VALUES (%s, %s, %s, 2, %s, %s, 'user', 1, %s, %s)",
                        (review_id, reply_id, reply_id,
                         random.choice(["不客气，还会再来的！", "希望你们越做越好！"]),
                         user_id,
                         (review_time + timedelta(hours=random.randint(1, 24))).strftime(FMT),
                         (review_time + timedelta(hours=random.randint(1, 24))).strftime(FMT)),
                    )
                    total_replies += 1

        cur.execute("""
            UPDATE sp_products p
            SET rating_average = (
                SELECT ROUND(COALESCE(AVG(r.overall_rating), 0), 2)
                FROM rev_reviews r
                WHERE r.spu_id = p.id AND r.status = 1
            ),
            rating_count = (
                SELECT COUNT(*)
                FROM rev_reviews r
                WHERE r.spu_id = p.id AND r.status = 1
            )
            WHERE p.deleted_at IS NULL
        """)

        # rev_review_statistics：按 SPU 聚合评价统计
        cur.execute("""
            INSERT INTO rev_review_statistics (target_type, target_id,
                rating_1_count, rating_2_count, rating_3_count, rating_4_count, rating_5_count,
                total_count, avg_rating, good_rate, has_media_count, has_content_count)
            SELECT
                1 AS target_type,
                r.spu_id AS target_id,
                COUNT(*) FILTER (WHERE r.overall_rating = 1),
                COUNT(*) FILTER (WHERE r.overall_rating = 2),
                COUNT(*) FILTER (WHERE r.overall_rating = 3),
                COUNT(*) FILTER (WHERE r.overall_rating = 4),
                COUNT(*) FILTER (WHERE r.overall_rating = 5),
                COUNT(*),
                ROUND(AVG(r.overall_rating)::numeric, 2),
                ROUND(COUNT(*) FILTER (WHERE r.overall_rating >= 4) * 100.0 / NULLIF(COUNT(*), 0), 2),
                COUNT(*) FILTER (WHERE r.has_media = 1),
                COUNT(*) FILTER (WHERE r.content IS NOT NULL AND r.content != '')
            FROM rev_reviews r
            WHERE r.status = 1
            GROUP BY r.spu_id
            ON CONFLICT (target_type, target_id) DO NOTHING
        """)
        stats_count = cur.rowcount

        # rev_review_usefulness：为部分评价生成"有用"标记
        cur.execute("SELECT id, user_id, spu_id FROM rev_reviews WHERE status = 1 ORDER BY RANDOM() LIMIT 200")
        usefulness_count = 0
        for rv_id, rv_user, rv_spu in cur.fetchall():
            cur.execute(
                "SELECT id FROM usr_users WHERE deleted_at IS NULL ORDER BY RANDOM() LIMIT 1"
            )
            voter = cur.fetchone()
            if voter:
                cur.execute(
                    "INSERT INTO rev_review_usefulness (review_id, user_id) "
                    "VALUES (%s, %s) ON CONFLICT DO NOTHING",
                    (rv_id, voter[0]),
                )
                if cur.rowcount:
                    usefulness_count += 1

    conn.commit()
    print(f"  评价: {total_reviews}, 媒体: {total_media}, 回复: {total_replies}, 审核日志: {total_audit_logs}, 统计: {stats_count}, 有用: {usefulness_count}")
    print("评价中心 ✅\n")
