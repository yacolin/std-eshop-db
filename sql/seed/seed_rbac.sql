-- ============================================================================
-- RBAC 数据初始化
-- 权限 → 角色 → 角色-权限关联 → 用户 → 用户-角色关联 → 地址
-- ============================================================================

USE eshop_db;

-- ==================== 权限 ====================
-- product 模块 (10000-19999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('product:read',   '查看产品',   'product',  'read',   'product', 11000, 1),
('product:create', '创建产品',   'product',  'create', 'product', 11050, 1),
('product:update', '编辑产品',   'product',  'update', 'product', 11100, 1),
('product:delete', '删除产品',   'product',  'delete', 'product', 11150, 1),

('category:read',   '查看分类',   'category', 'read',   'product', 11500, 1),
('category:create', '创建分类',   'category', 'create', 'product', 11550, 1),
('category:update', '编辑分类',   'category', 'update', 'product', 11600, 1),
('category:delete', '删除分类',   'category', 'delete', 'product', 11650, 1),

('brand:read',   '查看品牌',   'brand', 'read',   'product', 12000, 1),
('brand:create', '创建品牌',   'brand', 'create', 'product', 12050, 1),
('brand:update', '编辑品牌',   'brand', 'update', 'product', 12100, 1),
('brand:delete', '删除品牌',   'brand', 'delete', 'product', 12150, 1),

('sku:read',   '查看 SKU',   'sku', 'read',   'product', 12500, 1),
('sku:create', '创建 SKU',   'sku', 'create', 'product', 12550, 1),
('sku:update', '编辑 SKU',   'sku', 'update', 'product', 12600, 1),
('sku:delete', '删除 SKU',   'sku', 'delete', 'product', 12650, 1),

('attr:read',      '查看属性',   'attr',     'read',   'product', 13000, 1),
('attr:create',    '创建属性',   'attr',     'create', 'product', 13050, 1),
('attr:update',    '编辑属性',   'attr',     'update', 'product', 13100, 1),
('attr:delete',    '删除属性',   'attr',     'delete', 'product', 13150, 1),
('attr_val:read',   '查看属性值', 'attr_val', 'read',   'product', 13250, 1),
('attr_val:create', '创建属性值', 'attr_val', 'create', 'product', 13300, 1),
('attr_val:update', '编辑属性值', 'attr_val', 'update', 'product', 13350, 1),
('attr_val:delete', '删除属性值', 'attr_val', 'delete', 'product', 13400, 1);

-- inventory 模块 (20000-29999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('inventory:read',    '查看库存',   'inventory', 'read',    'inventory', 21000, 1),
('inventory:create',  '创建库存',   'inventory', 'create',  'inventory', 21050, 1),
('inventory:update',  '编辑库存',   'inventory', 'update',  'inventory', 21100, 1),
('inventory:reserve', '库存操作',   'inventory', 'reserve', 'inventory', 21150, 1);

-- trade 模块 (30000-39999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('order:read',         '查看订单',   'order', 'read',   'trade', 31000, 1),
('order:create',       '创建订单',   'order', 'create', 'trade', 31050, 1),
('order:update',       '编辑订单',   'order', 'update', 'trade', 31100, 1),
('order:cancel',       '取消订单',   'order', 'cancel', 'trade', 31150, 1),

('cart:read',   '查看购物车',   'cart', 'read',   'trade', 31500, 1),
('cart:create', '添加商品',     'cart', 'add',    'trade', 31550, 1),
('cart:update', '编辑购物车',   'cart', 'update', 'trade', 31600, 1),
('cart:delete', '删除商品',     'cart', 'delete', 'trade', 31650, 1),

('payment:read',   '查看支付',   'payment', 'read',   'trade', 32000, 1),
('payment:create', '发起支付',   'payment', 'create', 'trade', 32050, 1),
('payment:update', '更新支付',   'payment', 'update', 'trade', 32100, 1),

('refund:read',   '查看退款',   'refund', 'read',   'trade', 32500, 1),
('refund:create', '申请退款',   'refund', 'create', 'trade', 32550, 1),
('refund:update', '处理退款',   'refund', 'update', 'trade', 32600, 1);

-- delivery 模块 (33000-33999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('delivery:read',   '查看物流',   'delivery', 'read',   'trade', 33000, 1),
('delivery:create', '创建发货',   'delivery', 'create', 'trade', 33050, 1),
('delivery:update', '编辑物流',   'delivery', 'update', 'trade', 33100, 1);

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('promotion:read',   '查看促销',   'promotion', 'read',   'marketing', 41000, 1),
('promotion:create', '创建促销',   'promotion', 'create', 'marketing', 41050, 1),
('promotion:update', '编辑促销',   'promotion', 'update', 'marketing', 41100, 1),
('promotion:delete', '删除促销',   'promotion', 'delete', 'marketing', 41150, 1);

-- review 模块 (50000-59999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('review:read',     '查看评论',   'review', 'read',     'review', 51000, 1),
('review:create',   '发表评论',   'review', 'create',   'review', 51050, 1),
('review:delete',   '删除评论',   'review', 'delete',   'review', 51100, 1),
('review:moderate', '审核评论',   'review', 'moderate', 'review', 51150, 1),
('review:reply',    '回复评论',   'review', 'reply',    'review', 51200, 1);

-- user 模块 (60000-69999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('user:read',   '查看用户',   'user', 'read',   'user', 61000, 1),
('user:create', '创建用户',   'user', 'create', 'user', 61050, 1),
('user:update', '编辑用户',   'user', 'update', 'user', 61100, 1),
('user:delete', '删除用户',   'user', 'delete', 'user', 61150, 1),

('role:read',   '查看角色',   'role', 'read',   'user', 61500, 1),
('role:create', '创建角色',   'role', 'create', 'user', 61550, 1),
('role:update', '编辑角色',   'role', 'update', 'user', 61600, 1),
('role:delete', '删除角色',   'role', 'delete', 'user', 61650, 1),

('address:read',   '查看地址',   'address', 'read',   'user', 62000, 1),
('address:create', '创建地址',   'address', 'create', 'user', 62050, 1),
('address:update', '编辑地址',   'address', 'update', 'user', 62100, 1),
('address:delete', '删除地址',   'address', 'delete', 'user', 62150, 1),

('points:read',   '查看积分',   'points', 'read',   'user', 63000, 1),
('level:read',    '查看等级',   'level',  'read',   'user', 63050, 1);

-- base 模块 (70000-79999) — 通知

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('notification:read',   '查看通知',   'notification', 'read',   'base', 71000, 1),
('notification:update', '标记已读',   'notification', 'update', 'base', 71050, 1),
('notification:delete', '删除通知',   'notification', 'delete', 'base', 71100, 1),
('notification:send',   '发送通知',   'notification', 'send',   'base', 71150, 1);

-- dashboard 模块 (80000-89999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('dashboard:read', '查看仪表盘', 'dashboard', 'read', 'dashboard', 81000, 1);


-- ==================== 用户等级 ====================

INSERT INTO usr_levels (name, level, min_points, max_points, discount_rate, free_shipping, points_multiplier, benefits) VALUES
('青铜会员', 1, 0,     999,  1000, 0, 1.00, '{"birthday_gift": false}'),
('白银会员', 2, 1000,  4999, 950,  0, 1.20, '{"birthday_gift": false}'),
('黄金会员', 3, 5000,  19999, 900, 1, 1.50, '{"birthday_gift": true}'),
('钻石会员', 4, 20000, 0,     850, 1, 2.00, '{"birthday_gift": true, "exclusive_coupon": true}');

-- ==================== 角色 ====================

INSERT INTO sys_roles (name, display_name, description, role_type, sort_order, status) VALUES
('admin',     '管理员',     '系统管理员，拥有所有权限',                         'builtin', 1,  1),
('operator',  '运营人员',   '订单处理、退款审核、评论管理、通知发送',          'builtin', 2,  1),
('editor',    '内容编辑',   '商品/分类内容维护',                                'builtin', 3,  1),
('warehouse', '仓库管理员', '库存管理、订单发货处理',                           'builtin', 4,  1),
('finance',   '财务人员',   '支付对账、退款审核处理',                          'builtin', 5,  1),
('user',      '普通用户',   '普通注册用户，拥有基本购物操作权限',               'builtin', 6,  1),
('merchant',  '商户用户',   '商户用户，拥有商品管理和订单处理权限',             'builtin', 7,  1),
('support',   '客服人员',   '客服人员，拥有订单和售后处理权限',                'builtin', 8,  1),
('analyst',   '数据分析师', '数据分析师，拥有只读数据查看权限',                'builtin', 9,  1);


-- ==================== 角色-权限关联 ====================

-- admin：所有权限
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'admin'), id FROM sys_permissions;

-- user：基础购物操作
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'user'), id FROM sys_permissions WHERE name IN (
    'product:read', 'category:read', 'brand:read', 'inventory:read', 'sku:read',
    'attr:read', 'attr_val:read',
    'address:read', 'address:create', 'address:update', 'address:delete',
    'order:read', 'order:create', 'order:cancel',
    'cart:read', 'cart:create', 'cart:update', 'cart:delete',
    'payment:read', 'payment:create',
    'refund:read', 'refund:create',
    'delivery:read',
    'review:read', 'review:create', 'review:delete',
    'notification:read', 'notification:update',
    'promotion:read',
    'user:read', 'user:update',
    'points:read', 'level:read'
);

-- operator：运营操作
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'operator'), id FROM sys_permissions WHERE name IN (
    'product:read', 'category:read', 'brand:read', 'inventory:read', 'sku:read',
    'attr:read', 'attr_val:read', 'address:read',
    'order:read', 'order:update', 'order:cancel',
    'payment:read', 'refund:read', 'refund:update',
    'delivery:read',
    'review:read', 'review:moderate', 'review:reply',
    'notification:read', 'notification:update', 'notification:send',
    'promotion:read',
    'user:read', 'points:read', 'level:read'
);

-- editor：内容维护
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'editor'), id FROM sys_permissions WHERE name IN (
    'product:read', 'product:create', 'product:update',
    'category:read', 'category:create', 'category:update',
    'inventory:read', 'sku:read',
    'attr:read', 'attr_val:read', 'address:read',
    'order:read',
    'promotion:read', 'promotion:create', 'promotion:update',
    'review:read', 'review:moderate', 'review:reply',
    'notification:read',
    'user:read'
);

-- warehouse：库存与发货
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'warehouse'), id FROM sys_permissions WHERE name IN (
    'product:read', 'category:read',
    'inventory:read', 'inventory:create', 'inventory:update', 'inventory:reserve',
    'sku:read', 'address:read',
    'order:read', 'order:update',
    'delivery:read', 'delivery:create',
    'notification:read'
);

-- finance：财务与退款
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'finance'), id FROM sys_permissions WHERE name IN (
    'order:read', 'payment:read', 'payment:update',
    'refund:read', 'refund:update',
    'product:read', 'sku:read', 'address:read',
    'notification:read', 'user:read'
);

-- merchant：商户管理
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'merchant'), id FROM sys_permissions WHERE name IN (
    'product:read', 'product:create', 'product:update',
    'category:read', 'inventory:read',
    'sku:read', 'sku:create', 'sku:update',
    'attr:read', 'attr_val:read', 'address:read',
    'order:read', 'order:update', 'order:cancel',
    'payment:read', 'refund:read',
    'delivery:read',
    'promotion:read',
    'review:read',
    'notification:read', 'notification:update',
    'dashboard:read',
    'user:read', 'points:read', 'level:read'
);

-- support：客服售后
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'support'), id FROM sys_permissions WHERE name IN (
    'product:read', 'category:read', 'sku:read',
    'attr:read', 'attr_val:read', 'address:read',
    'order:read', 'order:update', 'order:cancel',
    'payment:read', 'refund:read', 'refund:update',
    'delivery:read',
    'review:read', 'review:moderate', 'review:reply',
    'notification:read', 'notification:update', 'notification:send',
    'user:read', 'dashboard:read', 'points:read', 'level:read'
);

-- analyst：数据分析
INSERT INTO sys_role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys_roles WHERE name = 'analyst'), id FROM sys_permissions WHERE name IN (
    'product:read', 'category:read', 'brand:read', 'inventory:read',
    'order:read', 'cart:read', 'payment:read', 'refund:read',
    'delivery:read',
    'promotion:read', 'review:read', 'notification:read', 'user:read',
    'sku:read', 'attr:read', 'attr_val:read', 'address:read',
    'dashboard:read', 'points:read', 'level:read'
);


-- ==================== B端员工（sys_staff） ====================
-- 密码均为 "123456"，bcrypt hash（cost=10）

INSERT INTO sys_staff (username, password_hash, real_name, email, phone, status) VALUES
('admin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', '管理员', 'admin@eshop.dev', '13800000001', 1),
('colin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', '陈科林', 'colin@eshop.dev', '13800000002', 1);

INSERT INTO sys_staff_roles (staff_id, role_id) VALUES
(1, (SELECT id FROM sys_roles WHERE name = 'admin')),
(2, (SELECT id FROM sys_roles WHERE name = 'user'));


-- ==================== C端消费者（usr_users） ====================

INSERT INTO usr_users (username, password_hash, nickname, email, phone, status, register_source) VALUES
('colin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC', 'Colin', 'colin@eshop.dev', '13800000002', 1, 'web');

INSERT INTO usr_infos (user_id) VALUES (1);

-- C端用户不分配 B 端角色，通过接口权限和数据归属实现鉴权


-- ==================== 收货地址（公司 + 家） ====================

INSERT INTO usr_addresses (user_id, consignee, phone, country, province, city, district, detail, zip_code, tag, is_default) VALUES
(1, '陈科林', '13900139001', '中国', '广东省', '深圳市', '南山区', '科技园南区高新南一道2号飞亚达科技大厦12F', '518057', 'company', TRUE),
(1, '陈科林', '13900139002', '中国', '广东省', '广州市', '天河区', '珠江新城华夏路16号富力盈凯广场3001', '510623', 'home', FALSE);
