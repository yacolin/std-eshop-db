#!/usr/bin/env python3
"""
种子：用户中心 — B端员工 / C端用户 / 地址
"""
from seed_common import *


def seed_users(conn):
    with conn.cursor() as cur:
        # admin — B 端员工
        cur.execute("""
            INSERT IGNORE INTO sys_staff (id, username, password_hash, real_name, email, phone, status)
            VALUES (1, 'admin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC',
                    '管理员', 'admin@eshop.dev', '13800000001', 1)
        """)
        if cur.lastrowid:
            cur.execute("INSERT IGNORE INTO sys_staff_roles (staff_id, role_id) "
                        "VALUES (1, (SELECT id FROM sys_roles WHERE name = 'admin'))")

        # colin — B 端员工 + C 端消费者
        cur.execute("""
            INSERT IGNORE INTO sys_staff (username, password_hash, real_name, email, phone, status)
            VALUES ('colin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC',
                    '陈科林', 'colin@eshop.dev', '13800000002', 1)
        """)
        if cur.lastrowid:
            cur.execute("INSERT IGNORE INTO sys_staff_roles (staff_id, role_id) "
                        "VALUES (%s, (SELECT id FROM sys_roles WHERE name = 'user'))",
                        (cur.lastrowid,))

        cur.execute("""
            INSERT IGNORE INTO usr_users (id, username, password_hash, nickname, email, phone, status, register_source)
            VALUES (1, 'colin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC',
                    'Colin', 'colin@eshop.dev', '13800000002', 1, 'web')
        """)
        if cur.lastrowid:
            cur.execute("INSERT IGNORE INTO usr_infos (user_id) VALUES (1)")

        # colin 的收货地址（公司 + 家）
        cur.execute("DELETE FROM usr_addresses WHERE user_id = 1")
        cur.execute("""
            INSERT INTO usr_addresses (user_id, consignee, phone, country, province, city, district, detail, zip_code, tag, is_default)
            VALUES (1, '陈科林', '13900139001', '中国', '广东省', '深圳市', '南山区', '科技园南区高新南一道2号飞亚达科技大厦12F', '518057', 'company', 1)
        """)
        cur.execute("""
            INSERT INTO usr_addresses (user_id, consignee, phone, country, province, city, district, detail, zip_code, tag, is_default)
            VALUES (1, '陈科林', '13900139002', '中国', '广东省', '广州市', '天河区', '珠江新城华夏路16号富力盈凯广场3001', '510623', 'home', FALSE)
        """)
    conn.commit()
    print("  B端员工: admin, colin (固定)")
    print("  C端用户: colin (固定)")
    print("  地址: 公司 + 家 (2 条)")
    print("用户中心 ✅\n")
