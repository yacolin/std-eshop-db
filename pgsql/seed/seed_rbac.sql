-- ============================================================================
-- 完整种子数据（RBAC + 业务数据）
-- 按依赖顺序：清理 → 权限 → 角色 → 关联 → 等级 → 员工 → 消费者 → 地址
-- 执行方式：psql -U postgres -d eshop_db -f pgsql/seed/seed_rbac.sql
-- ============================================================================

SET session_replication_role = replica;

TRUNCATE TABLE sys_operation_logs;
TRUNCATE TABLE sys_staff_departments;
TRUNCATE TABLE sys_departments;
TRUNCATE TABLE sys_role_permissions;
TRUNCATE TABLE sys_permissions;
TRUNCATE TABLE sys_roles;
TRUNCATE TABLE usr_levels;
TRUNCATE TABLE sys_staff_roles;
TRUNCATE TABLE sys_staff;
TRUNCATE TABLE usr_points;
TRUNCATE TABLE usr_login_histories;
TRUNCATE TABLE usr_addresses;
TRUNCATE TABLE usr_infos;
TRUNCATE TABLE usr_users;

SET session_replication_role = default;

-- ==================== 权限 ====================
-- product 模块 (10000-19999)

INSERT INTO sys_permissions (name, display_name, resource, action, parent_id, category, sort_order, status) VALUES
('product:read',     '查看产品',   'product',   'read',   0, 'product', 11000, 1),
('product:create',   '创建产品',   'product',   'create', 0, 'product', 11050, 1),
('product:update',   '编辑产品',   'product',   'update', 0, 'product', 11100, 1),
('product:delete',   '删除产品',   'product',   'delete', 0, 'product', 11150, 1),

('category:read',    '查看分类',   'category',  'read',   0, 'product', 11500, 1),
('category:create',  '创建分类',   'category',  'create', 0, 'product', 11550, 1),
('category:update',  '编辑分类',   'category',  'update', 0, 'product', 11600, 1),
('category:delete',  '删除分类',   'category',  'delete', 0, 'product', 11650, 1),

('brand:read',       '查看品牌',   'brand',     'read',   0, 'product', 12000, 1),
('brand:create',     '创建品牌',   'brand',     'create', 0, 'product', 12050, 1),
('brand:update',     '编辑品牌',   'brand',     'update', 0, 'product', 12100, 1),
('brand:delete',     '删除品牌',   'brand',     'delete', 0, 'product', 12150, 1),

('sku:read',         '查看 SKU',   'sku',       'read',   0, 'product', 12500, 1),
('sku:create',       '创建 SKU',   'sku',       'create', 0, 'product', 12550, 1),
('sku:update',       '编辑 SKU',   'sku',       'update', 0, 'product', 12600, 1),
('sku:delete',       '删除 SKU',   'sku',       'delete', 0, 'product', 12650, 1),

('attribute:read',       '查看属性',   'attribute',      'read',   0, 'product', 13000, 1),
('attribute:create',     '创建属性',   'attribute',      'create', 0, 'product', 13050, 1),
('attribute:update',     '编辑属性',   'attribute',      'update', 0, 'product', 13100, 1),
('attribute:delete',     '删除属性',   'attribute',      'delete', 0, 'product', 13150, 1),
('attribute_val:read',   '查看属性值', 'attribute_val',  'read',   0, 'product', 13250, 1),
('attribute_val:create', '创建属性值', 'attribute_val',  'create', 0, 'product', 13300, 1),
('attribute_val:update', '编辑属性值', 'attribute_val',  'update', 0, 'product', 13350, 1),
('attribute_val:delete', '删除属性值', 'attribute_val',  'delete', 0, 'product', 13400, 1);

-- inventory 模块 (20000-29999)

INSERT INTO sys_permissions (name, display_name, resource, action, parent_id, category, sort_order, status) VALUES
('inventory:read',    '查看库存',        'inventory', 'read',    0, 'inventory', 21000, 1),
('inventory:create',  '创建库存记录',    'inventory', 'create',  0, 'inventory', 21050, 1),
('inventory:update',  '编辑库存',        'inventory', 'update',  0, 'inventory', 21100, 1),
('inventory:reserve', '库存预留/释放',   'inventory', 'reserve', 0, 'inventory', 21150, 1);

-- trade 模块 (30000-39999)

INSERT INTO sys_permissions (name, display_name, resource, action, parent_id, category, sort_order, status) VALUES
('order:read',     '查看订单',   'order', 'read',   0, 'trade', 31000, 1),
('order:create',   '创建订单',   'order', 'create', 0, 'trade', 31050, 1),
('order:update',   '编辑订单',   'order', 'update', 0, 'trade', 31100, 1),
('order:cancel',   '取消订单',   'order', 'cancel', 0, 'trade', 31150, 1),

('cart:read',   '查看购物车', 'cart', 'read',   0, 'trade', 31500, 1),
('cart:add',    '添加商品',   'cart', 'add',    0, 'trade', 31550, 1),
('cart:update', '编辑购物车', 'cart', 'update', 0, 'trade', 31600, 1),
('cart:delete', '删除商品',   'cart', 'delete', 0, 'trade', 31650, 1),

('payment:read',   '查看支付',   'payment', 'read',   0, 'trade', 32000, 1),
('payment:create', '发起支付',   'payment', 'create', 0, 'trade', 32050, 1),
('payment:update', '更新支付',   'payment', 'update', 0, 'trade', 32100, 1),

('refund:read',   '查看退款',   'refund', 'read',   0, 'trade', 32500, 1),
('refund:create', '申请退款',   'refund', 'create', 0, 'trade', 32550, 1),
('refund:update', '处理退款',   'refund', 'update', 0, 'trade', 32600, 1),

('delivery:read',   '查看物流',   'delivery', 'read',   0, 'trade', 33000, 1),
('delivery:create', '创建发货',   'delivery', 'create', 0, 'trade', 33050, 1),
('delivery:update', '编辑物流',   'delivery', 'update', 0, 'trade', 33100, 1);

-- marketing 模块 (40000-49999)

INSERT INTO sys_permissions (name, display_name, resource, action, parent_id, category, sort_order, status) VALUES
('promotion:read',   '查看促销',   'promotion', 'read',   0, 'marketing', 41000, 1),
('promotion:create', '创建促销',   'promotion', 'create', 0, 'marketing', 41050, 1),
('promotion:update', '编辑促销',   'promotion', 'update', 0, 'marketing', 41100, 1),
('promotion:delete', '删除促销',   'promotion', 'delete', 0, 'marketing', 41150, 1);

-- merchant 模块 (45000-49999)

INSERT INTO sys_permissions (name, display_name, resource, action, parent_id, category, sort_order, status) VALUES
('merchant:read',            '查看商家',       'merchant',          'read',    0, 'merchant', 45100, 1),
('merchant:create',          '创建商家',       'merchant',          'create',  0, 'merchant', 45150, 1),
('merchant:update',          '编辑商家',       'merchant',          'update',  0, 'merchant', 45200, 1),
('merchant:delete',          '删除商家',       'merchant',          'delete',  0, 'merchant', 45250, 1),

('merchant_bank:read',       '查看银行账户',   'merchant_bank',     'read',    0, 'merchant', 46000, 1),
('merchant_bank:create',     '添加银行账户',   'merchant_bank',     'create',  0, 'merchant', 46050, 1),
('merchant_bank:update',     '编辑银行账户',   'merchant_bank',     'update',  0, 'merchant', 46100, 1),
('merchant_bank:delete',     '删除银行账户',   'merchant_bank',     'delete',  0, 'merchant', 46150, 1),

('merchant_contact:read',    '查看联系人',     'merchant_contact',  'read',    0, 'merchant', 47000, 1),
('merchant_contact:create',  '添加联系人',     'merchant_contact',  'create',  0, 'merchant', 47050, 1),
('merchant_contact:update',  '编辑联系人',     'merchant_contact',  'update',  0, 'merchant', 47100, 1),
('merchant_contact:delete',  '删除联系人',     'merchant_contact',  'delete',  0, 'merchant', 47150, 1),

('merchant_qual:read',       '查看资质',       'merchant_qual',     'read',    0, 'merchant', 48000, 1),
('merchant_qual:create',     '上传资质',       'merchant_qual',     'create',  0, 'merchant', 48050, 1),
('merchant_qual:update',     '编辑资质',       'merchant_qual',     'update',  0, 'merchant', 48100, 1),
('merchant_qual:delete',     '删除资质',       'merchant_qual',     'delete',  0, 'merchant', 48150, 1),
('merchant_qual:audit',      '审核资质',       'merchant_qual',     'audit',   0, 'merchant', 48200, 1),

('merchant_withdraw:read',   '查看提现',       'merchant_withdraw', 'read',    0, 'merchant', 49000, 1),
('merchant_withdraw:approve','审核通过提现',   'merchant_withdraw', 'approve', 0, 'merchant', 49050, 1),
('merchant_withdraw:reject', '拒绝提现',       'merchant_withdraw', 'reject',  0, 'merchant', 49100, 1),

('merchant_balance:read',    '查看余额',       'merchant_balance',  'read',    0, 'merchant', 49500, 1);

-- review 模块 (50000-59999)

INSERT INTO sys_permissions (name, display_name, resource, action, parent_id, category, sort_order, status) VALUES
('review:read',     '查看评论',   'review', 'read',     0, 'review', 51000, 1),
('review:create',   '发表评论',   'review', 'create',   0, 'review', 51050, 1),
('review:moderate', '审核评论',   'review', 'moderate', 0, 'review', 51100, 1),
('review:reply',    '回复评论',   'review', 'reply',    0, 'review', 51150, 1),
('review:delete',   '删除评论',   'review', 'delete',   0, 'review', 51200, 1);

-- staff 模块 (60000-69999) — 角色 & 权限管理

INSERT INTO sys_permissions (name, display_name, resource, action, parent_id, category, sort_order, status) VALUES
('staff:read',     '查看员工',   'staff',       'read',   0, 'staff', 60000, 1),
('staff:create',   '创建员工',   'staff',       'create', 0, 'staff', 60050, 1),
('staff:update',   '编辑员工',   'staff',       'update', 0, 'staff', 60100, 1),
('staff:delete',   '删除员工',   'staff',       'delete', 0, 'staff', 60150, 1),

('role:read',     '查看角色',   'role',       'read',   0, 'staff', 61000, 1),
('role:create',   '创建角色',   'role',       'create', 0, 'staff', 61050, 1),
('role:update',   '编辑角色',   'role',       'update', 0, 'staff', 61100, 1),
('role:delete',   '删除角色',   'role',       'delete', 0, 'staff', 61150, 1),

('permission:read',   '查看权限',   'permission', 'read',   0, 'staff', 61500, 1),
('permission:create', '创建权限',   'permission', 'create', 0, 'staff', 61550, 1),
('permission:update', '编辑权限',   'permission', 'update', 0, 'staff', 61600, 1),
('permission:delete', '删除权限',   'permission', 'delete', 0, 'staff', 61650, 1),

('department:read',     '查看部门',   'department', 'read',   0, 'staff', 62000, 1),
('department:create',   '创建部门',   'department', 'create', 0, 'staff', 62050, 1),
('department:update',   '编辑部门',   'department', 'update', 0, 'staff', 62100, 1),
('department:delete',   '删除部门',   'department', 'delete', 0, 'staff', 62150, 1),

('operation_log:read',  '查看操作日志', 'operation_log', 'read', 0, 'staff', 63000, 1);

-- user 模块 (70000-79999)

INSERT INTO sys_permissions (name, display_name, resource, action, parent_id, category, sort_order, status) VALUES
('user:read',     '查看用户',   'user',    'read',   0, 'user', 71000, 1),
('user:create',   '创建用户',   'user',    'create', 0, 'user', 71050, 1),
('user:update',   '编辑用户',   'user',    'update', 0, 'user', 71100, 1),
('user:delete',   '删除用户',   'user',    'delete', 0, 'user', 71150, 1),

('address:read',   '查看地址',   'address', 'read',   0, 'user', 71500, 1),
('address:create', '创建地址',   'address', 'create', 0, 'user', 71550, 1),
('address:update', '编辑地址',   'address', 'update', 0, 'user', 71600, 1),
('address:delete', '删除地址',   'address', 'delete', 0, 'user', 71650, 1),

('points:read', '查看积分', 'points', 'read', 0, 'user', 72000, 1),
('level:read',  '查看等级', 'level',  'read', 0, 'user', 72050, 1);

-- base 模块 (80000-89999) — 通知

INSERT INTO sys_permissions (name, display_name, resource, action, parent_id, category, sort_order, status) VALUES
('notification:read',   '查看通知',   'notification', 'read',   0, 'base', 81000, 1),
('notification:create', '发送通知',   'notification', 'create', 0, 'base', 81050, 1),
('notification:update', '标记已读',   'notification', 'update', 0, 'base', 81100, 1),
('notification:delete', '删除通知',   'notification', 'delete', 0, 'base', 81150, 1);

-- dashboard 模块 (90000-99999)

INSERT INTO sys_permissions (name, display_name, resource, action, parent_id, category, sort_order, status) VALUES
('dashboard:read', '查看仪表盘', 'dashboard', 'read', 0, 'dashboard', 91000, 1);


-- ==================== 角色 ====================

INSERT INTO sys_roles (name, display_name, description, role_type, sort_order, status) VALUES
('admin',     '管理员',     '系统管理员，拥有所有权限',                             'builtin',  1, 1),
('operator',  '运营人员',   '订单处理、退款审核、评论管理、通知发送',              'builtin',  2, 1),
('editor',    '内容编辑',   '商品/分类/品牌/属性内容维护',                         'builtin',  3, 1),
('warehouse', '仓库管理员', '库存管理、订单发货处理',                               'builtin',  4, 1),
('finance',   '财务人员',   '支付对账、退款审核处理',                              'builtin',  5, 1),
('user',      '普通用户',   '普通注册用户，拥有基本购物操作权限',                   'builtin',  6, 1),
('merchant',  '商户用户',   '商户用户，拥有商品管理和订单处理权限',                 'builtin',  7, 1),
('support',   '客服人员',   '客服人员，拥有订单和售后处理权限',                    'builtin',  8, 1),
('analyst',   '数据分析师', '数据分析师，拥有只读数据查看权限',                    'builtin',  9, 1);


-- ==================== 角色-权限关联 ====================

-- admin：所有权限
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'admin'), id FROM sys_permissions;

-- user：基础购物操作
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'user'), id FROM sys_permissions WHERE name IN (
    'product:read', 'category:read', 'brand:read', 'inventory:read', 'sku:read',
    'attribute:read', 'attribute_val:read',
    'address:read', 'address:create', 'address:update', 'address:delete',
    'order:read', 'order:create', 'order:cancel',
    'cart:read', 'cart:add', 'cart:update', 'cart:delete',
    'payment:read', 'payment:create',
    'refund:read', 'refund:create',
    'delivery:read',
    'review:read', 'review:create', 'review:delete',
    'notification:read',
    'promotion:read',
    'user:read', 'user:update',
    'points:read', 'level:read'
);

-- operator：运营操作
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'operator'), id FROM sys_permissions WHERE name IN (
    'product:read', 'category:read', 'brand:read', 'inventory:read', 'sku:read',
    'attribute:read', 'attribute_val:read',
    'address:read',
    'order:read', 'order:update', 'order:cancel',
    'payment:read', 'refund:read', 'refund:update',
    'delivery:read',
    'promotion:read',
    'merchant:read', 'merchant:create', 'merchant:update',
    'merchant_bank:read', 'merchant_bank:create', 'merchant_bank:update', 'merchant_bank:delete',
    'merchant_contact:read', 'merchant_contact:create', 'merchant_contact:update', 'merchant_contact:delete',
    'merchant_qual:read', 'merchant_qual:create', 'merchant_qual:update', 'merchant_qual:delete', 'merchant_qual:audit',
    'merchant_withdraw:read', 'merchant_withdraw:approve', 'merchant_withdraw:reject',
    'merchant_balance:read',
    'review:read', 'review:moderate', 'review:reply',
    'notification:read', 'notification:update', 'notification:create',
    'user:read', 'points:read', 'level:read',
    'staff:read',
    'department:read', 'department:create', 'department:update', 'department:delete',
    'operation_log:read',
    'dashboard:read'
);

-- editor：内容维护
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'editor'), id FROM sys_permissions WHERE name IN (
    'product:read', 'product:create', 'product:update',
    'category:read', 'category:create', 'category:update',
    'brand:read', 'brand:create', 'brand:update',
    'inventory:read',
    'sku:read', 'sku:create', 'sku:update',
    'attribute:read', 'attribute:create', 'attribute:update',
    'attribute_val:read', 'attribute_val:create', 'attribute_val:update', 'attribute_val:delete',
    'address:read',
    'order:read',
    'promotion:read', 'promotion:create', 'promotion:update',
    'review:read', 'review:moderate', 'review:reply',
    'notification:read', 'notification:create',
    'user:read'
);

-- warehouse：库存与发货
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'warehouse'), id FROM sys_permissions WHERE name IN (
    'product:read', 'category:read',
    'inventory:read', 'inventory:create', 'inventory:update', 'inventory:reserve',
    'sku:read', 'address:read',
    'order:read', 'order:update',
    'delivery:read', 'delivery:create', 'delivery:update',
    'notification:read'
);

-- finance：财务与退款
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'finance'), id FROM sys_permissions WHERE name IN (
    'order:read', 'payment:read', 'payment:update',
    'refund:read', 'refund:update',
    'product:read', 'sku:read', 'address:read',
    'merchant_balance:read', 'merchant_withdraw:read',
    'notification:read', 'user:read'
);

-- merchant：商户管理
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'merchant'), id FROM sys_permissions WHERE name IN (
    'product:read', 'product:create', 'product:update',
    'category:read', 'brand:read', 'inventory:read',
    'sku:read', 'sku:create', 'sku:update',
    'attribute:read', 'attribute_val:read',
    'address:read',
    'order:read', 'order:update', 'order:cancel',
    'payment:read', 'refund:read',
    'delivery:read',
    'promotion:read',
    'review:read',
    'merchant:read', 'merchant:update',
    'merchant_bank:read', 'merchant_bank:create', 'merchant_bank:update', 'merchant_bank:delete',
    'merchant_contact:read', 'merchant_contact:create', 'merchant_contact:update', 'merchant_contact:delete',
    'merchant_qual:read', 'merchant_qual:create', 'merchant_qual:update', 'merchant_qual:delete',
    'merchant_withdraw:read',
    'merchant_balance:read',
    'notification:read', 'notification:update',
    'dashboard:read',
    'user:read', 'points:read', 'level:read'
);

-- support：客服售后
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'support'), id FROM sys_permissions WHERE name IN (
    'product:read', 'category:read', 'sku:read',
    'attribute:read', 'attribute_val:read',
    'address:read',
    'order:read', 'order:update', 'order:cancel',
    'payment:read', 'refund:read', 'refund:update',
    'delivery:read',
    'review:read', 'review:moderate', 'review:reply',
    'merchant:read',
    'merchant_bank:read',
    'merchant_contact:read',
    'merchant_qual:read',
    'merchant_withdraw:read',
    'merchant_balance:read',
    'notification:read', 'notification:update', 'notification:create',
    'user:read', 'dashboard:read', 'points:read', 'level:read'
);

-- analyst：数据分析
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'analyst'), id FROM sys_permissions WHERE name IN (
    'product:read', 'category:read', 'brand:read', 'inventory:read',
    'order:read', 'cart:read', 'payment:read', 'refund:read',
    'delivery:read',
    'promotion:read', 'review:read', 'notification:read',
    'sku:read', 'attribute:read', 'attribute_val:read', 'address:read',
    'merchant:read', 'merchant_bank:read',
    'merchant_contact:read', 'merchant_qual:read',
    'merchant_withdraw:read', 'merchant_balance:read',
    'dashboard:read', 'user:read', 'points:read', 'level:read'
);


-- ==================== 用户等级 ====================

INSERT INTO usr_levels (name, level, min_points, discount_rate, free_shipping, points_multiplier, benefits) VALUES
('青铜会员', 1, 0,     1000, 0, 1.00, '{"birthday_gift": false}'),
('白银会员', 2, 1000,  950,  0, 1.20, '{"birthday_gift": false}'),
('黄金会员', 3, 5000,  900, 1, 1.50, '{"birthday_gift": true}'),
('钻石会员', 4, 20000, 850, 1, 2.00, '{"birthday_gift": true, "exclusive_coupon": true}');


-- ==================== B端员工（sys_staff） ====================
-- 密码均为 "123456"，bcrypt hash（cost=10）

INSERT INTO sys_staff (username, password_hash, real_name, email, phone, status) VALUES
('admin',    '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', '管理员',     'admin@eshop.dev',       '13800000001', 1),
('colin',    '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', '陈科林',     'colin@eshop.dev',       '13800000002', 1),
('op_user',  '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', '运营小张',   'operator@eshop.dev',    '13800000003', 1),
('editor',   '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', '编辑小李',   'editor@eshop.dev',      '13800000004', 1),
('wh_user',  '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', '仓库小王',   'warehouse@eshop.dev',   '13800000005', 1),
('fin_user', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', '财务小赵',   'finance@eshop.dev',     '13800000006', 1),
('mch_user', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', '商户小刘',   'merchant@eshop.dev',    '13800000007', 1),
('spt_user', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', '客服小陈',   'support@eshop.dev',     '13800000008', 1),
('aly_user', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', '分析师小周', 'analyst@eshop.dev',     '13800000009', 1);

INSERT INTO sys_staff_roles (staff_id, role_id) VALUES
(1,  (SELECT id FROM sys_roles WHERE name = 'admin')),
(2,  (SELECT id FROM sys_roles WHERE name = 'user')),
(3,  (SELECT id FROM sys_roles WHERE name = 'operator')),
(4,  (SELECT id FROM sys_roles WHERE name = 'editor')),
(5,  (SELECT id FROM sys_roles WHERE name = 'warehouse')),
(6,  (SELECT id FROM sys_roles WHERE name = 'finance')),
(7,  (SELECT id FROM sys_roles WHERE name = 'merchant')),
(8,  (SELECT id FROM sys_roles WHERE name = 'support')),
(9,  (SELECT id FROM sys_roles WHERE name = 'analyst'));


-- ==================== C端消费者（usr_users） ====================

INSERT INTO usr_users (username, password_hash, nickname, email, phone, status, register_source) VALUES
('colin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', 'Colin', 'colin@eshop.dev', '13800000002', 1, 'web');

INSERT INTO usr_infos (user_id) VALUES (1);

-- C端用户不分配 B 端角色，通过接口权限和数据归属实现鉴权


-- ==================== 收货地址（公司 + 家） ====================

INSERT INTO usr_addresses (user_id, consignee, phone, country, province, city, district, detail, zip_code, tag, is_default) VALUES
(1, '陈科林', '13900139001', '中国', '广东省', '深圳市', '南山区', '科技园南区高新南一道2号飞亚达科技大厦12F', '518057', 'company', 1),
(1, '陈科林', '13900139002', '中国', '广东省', '广州市', '天河区', '珠江新城华夏路16号富力盈凯广场3001', '510623', 'home', NULL);
