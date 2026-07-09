#!/usr/bin/env python3
"""
种子：商户中心 — 商家 / 联系人 / 银行账户 / 资质 / 余额 / 角色 / 权限 / 员工绑定
"""
from seed_common import *


def seed_merchant(conn):
    now = datetime.now()
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM sys_staff WHERE deleted_at IS NULL")
        staff_list = [u[0] for u in cur.fetchall()]

        for mch_name, mch_type, mch_level, contact, phone in MERCHANTS:
            code = f"MCH{random.randint(10000, 99999)}"
            cur.execute(
                "INSERT INTO mch_merchants (merchant_name, merchant_code, merchant_type, merchant_level, "
                "contact_person, contact_phone, status, audit_status, commission_rate, settlement_cycle, "
                "settled_at, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, 1, 1, %s, 1, %s, %s, %s)",
                (mch_name, code, mch_type, mch_level, contact, phone,
                 random.randint(10, 80),
                 now.strftime(FMT), now.strftime(FMT), now.strftime(FMT)),
            )
            merchant_id = cur.lastrowid

            for r in range(random.randint(1, 2)):
                name = f"{random.choice(['张','李','王','赵','刘'])}{random.choice(['伟','芳','娜','强','敏'])}"
                cur.execute(
                    "INSERT INTO mch_merchant_contacts (merchant_id, contact_name, contact_phone, contact_role, is_primary) "
                    "VALUES (%s, %s, %s, %s, %s)",
                    (merchant_id, name, f"138{random.randint(10000000, 99999999)}",
                     random.choice(["finance", "operation", "legal"]),
                     1 if r == 0 else 0),
                )

            cur.execute(
                "INSERT INTO mch_merchant_bank_accounts (merchant_id, bank_name, bank_branch, account_name, account_no, "
                "account_type, is_default, status) VALUES (%s, %s, %s, %s, %s, %s, 1, 1)",
                (merchant_id,
                 random.choice(["中国工商银行", "中国建设银行", "中国银行", "招商银行"]),
                 random.choice(["上海分行", "北京分行", "深圳分行", "广州分行"]),
                 mch_name, f"{random.randint(100000000000, 999999999999)}",
                 random.choice([1, 2])),
            )

            for qual in ["business_license", "brand_authorization"]:
                cur.execute(
                    "INSERT INTO mch_merchant_qualifications (merchant_id, qualification_type, qualification_name, "
                    "file_url, expire_at, status) VALUES (%s, %s, %s, %s, %s, 1)",
                    (merchant_id, qual, f"{mch_name}_{qual}",
                     f"https://cdn.eshop.dev/qual/{merchant_id}/{qual}.pdf",
                     (now + timedelta(days=random.randint(180, 730))).strftime(FMT)),
                )

            cur.execute(
                "INSERT INTO mch_merchant_balances (merchant_id, available_balance, freeze_balance, version) "
                "VALUES (%s, %s, %s, 0)",
                (merchant_id, random.randint(1000000, 50000000), random.randint(0, 500000)),
            )

            # 创建商家角色
            MCH_ROLES = [
                ('manager',          '店长',   '商家管理员，拥有商家所有权限',                       1),
                ('editor',           '编辑',   '商品/分类/品牌/属性内容维护',                       2),
                ('customer_service', '客服',   '订单处理和售后服务',                               3),
                ('finance',          '财务',   '资金结算和提现管理',                               4),
                ('warehouse',        '仓库',   '库存管理和订单发货',                               5),
            ]

            MCH_ROLE_PERMS = {
                'manager':          ['*'],
                'editor':           ['product:read', 'product:create', 'product:update',
                                     'category:read', 'brand:read',
                                     'sku:read', 'sku:create', 'sku:update',
                                     'attribute:read', 'attribute_val:read',
                                     'inventory:read',
                                     'promotion:read', 'review:read',
                                     'merchant:read',
                                     'notification:read', 'notification:create'],
                'customer_service': ['product:read', 'category:read', 'sku:read',
                                     'order:read', 'order:update', 'order:cancel',
                                     'payment:read', 'refund:read', 'refund:update',
                                     'delivery:read',
                                     'review:read', 'review:reply',
                                     'merchant:read',
                                     'notification:read', 'notification:create', 'notification:update',
                                     'user:read', 'points:read', 'level:read'],
                'finance':          ['order:read', 'payment:read', 'refund:read', 'refund:update',
                                     'merchant_balance:read', 'merchant_withdraw:read',
                                     'merchant:read', 'merchant_bank:read',
                                     'product:read', 'sku:read',
                                     'notification:read'],
                'warehouse':        ['product:read', 'sku:read',
                                     'inventory:read', 'inventory:create', 'inventory:update', 'inventory:reserve',
                                     'order:read', 'order:update',
                                     'delivery:read', 'delivery:create', 'delivery:update',
                                     'notification:read'],
            }

            created_roles = {}
            for rname, rdisplay, rdesc, rsort in MCH_ROLES:
                cur.execute(
                    "INSERT INTO mch_merchant_roles (merchant_id, name, display_name, description, role_type, sort_order, status) "
                    "VALUES (%s, %s, %s, %s, 'builtin', %s, 1)",
                    (merchant_id, rname, rdisplay, rdesc, rsort),
                )
                role_id = cur.lastrowid
                created_roles[rname] = role_id

                perms = MCH_ROLE_PERMS.get(rname, [])
                if perms == ['*']:
                    cur.execute(
                        "INSERT INTO mch_merchant_role_permissions (merchant_id, role_id, permission_name) "
                        "SELECT %s, %s, name FROM sys_permissions",
                        (merchant_id, role_id),
                    )
                else:
                    for perm in perms:
                        cur.execute(
                            "INSERT IGNORE INTO mch_merchant_role_permissions (merchant_id, role_id, permission_name) "
                            "VALUES (%s, %s, %s)",
                            (merchant_id, role_id, perm),
                        )

            # 将员工分配到不同角色
            if staff_list:
                shuffled = staff_list[:]
                random.shuffle(shuffled)
                role_names = list(created_roles.keys())
                for idx, sid in enumerate(shuffled[:min(len(shuffled), 5)]):
                    role_name = role_names[idx % len(role_names)]
                    role_id = created_roles[role_name]
                    cur.execute(
                        "INSERT IGNORE INTO mch_merchant_users (merchant_id, staff_id, role_id, status) "
                        "VALUES (%s, %s, %s, 1)",
                        (merchant_id, sid, role_id),
                    )

        print(f"  商户: {len(MERCHANTS)}")
    conn.commit()
    print("商户中心 ✅\n")
