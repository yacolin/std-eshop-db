#!/usr/bin/env python3
"""
种子：通知模板
"""
from seed_common import *


def seed_notification(conn):
    NOTIFY_CHANNEL_MAP = {1: 'in_app', 2: 'push', 3: 'sms', 4: 'email', 5: 'wechat_template'}
    with conn.cursor() as cur:
        for code, channel, title, content, category, priority in NOTIFICATION_TEMPLATES:
            channel = NOTIFY_CHANNEL_MAP.get(channel, 'in_app')
            cur.execute(
                "INSERT INTO base_notification_templates "
                "(template_code, channel, title_template, content_template, category, priority, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, 1) "
                "ON CONFLICT DO NOTHING",
                (code, channel, title, content, category, priority),
            )
    conn.commit()
    print(f"  通知模板: {len(NOTIFICATION_TEMPLATES)} 条")
    print("通知模板 ✅\n")
