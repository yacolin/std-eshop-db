-- ============================================================================
-- RBAC 数据初始化
-- 权限 → 角色 → 角色-权限关联
-- 按菜单顺序排列：product → inventory → trade → marketing → merchant → review → staff → user → base → dashboard
-- ============================================================================

USE eshop_db;

-- ==================== 权限 ====================
-- product 模块 (10000-19999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('product:read',     '查看产品',   'product',   'read',   'product', 11000, 1),
('product:create',   '创建产品',   'product',   'create', 'product', 11050, 1),
('product:update',   '编辑产品',   'product',   'update', 'product', 11100, 1),
('product:delete',   '删除产品',   'product',   'delete', 'product', 11150, 1),

('category:read',    '查看分类',   'category',  'read',   'product', 11500, 1),
('category:create',  '创建分类',   'category',  'create', 'product', 11550, 1),
('category:update',  '编辑分类',   'category',  'update', 'product', 11600, 1),
('category:delete',  '删除分类',   'category',  'delete', 'product', 11650, 1),

('brand:read',       '查看品牌',   'brand',     'read',   'product', 12000, 1),
('brand:create',     '创建品牌',   'brand',     'create', 'product', 12050, 1),
('brand:update',     '编辑品牌',   'brand',     'update', 'product', 12100, 1),
('brand:delete',     '删除品牌',   'brand',     'delete', 'product', 12150, 1),

('sku:read',         '查看 SKU',   'sku',       'read',   'product', 12500, 1),
('sku:create',       '创建 SKU',   'sku',       'create', 'product', 12550, 1),
('sku:update',       '编辑 SKU',   'sku',       'update', 'product', 12600, 1),
('sku:delete',       '删除 SKU',   'sku',       'delete', 'product', 12650, 1),

('attribute:read',       '查看属性',   'attribute',      'read',   'product', 13000, 1),
('attribute:create',     '创建属性',   'attribute',      'create', 'product', 13050, 1),
('attribute:update',     '编辑属性',   'attribute',      'update', 'product', 13100, 1),
('attribute:delete',     '删除属性',   'attribute',      'delete', 'product', 13150, 1),
('attribute_val:read',   '查看属性值', 'attribute_val',  'read',   'product', 13250, 1),
('attribute_val:create', '创建属性值', 'attribute_val',  'create', 'product', 13300, 1),
('attribute_val:update', '编辑属性值', 'attribute_val',  'update', 'product', 13350, 1),
('attribute_val:delete', '删除属性值', 'attribute_val',  'delete', 'product', 13400, 1);

-- inventory 模块 (20000-29999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('inventory:read',    '查看库存',        'inventory', 'read',    'inventory', 21000, 1),
('inventory:create',  '创建库存记录',    'inventory', 'create',  'inventory', 21050, 1),
('inventory:update',  '编辑库存',        'inventory', 'update',  'inventory', 21100, 1),
('inventory:reserve', '库存预留/释放',   'inventory', 'reserve', 'inventory', 21150, 1);

-- trade 模块 (30000-39999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('order:read',     '查看订单',   'order', 'read',   'trade', 31000, 1),
('order:create',   '创建订单',   'order', 'create', 'trade', 31050, 1),
('order:update',   '编辑订单',   'order', 'update', 'trade', 31100, 1),
('order:cancel',   '取消订单',   'order', 'cancel', 'trade', 31150, 1),

('cart:read',   '查看购物车', 'cart', 'read',   'trade', 31500, 1),
('cart:add',    '添加商品',   'cart', 'add',    'trade', 31550, 1),
('cart:update', '编辑购物车', 'cart', 'update', 'trade', 31600, 1),
('cart:delete', '删除商品',   'cart', 'delete', 'trade', 31650, 1),

('payment:read',   '查看支付',   'payment', 'read',   'trade', 32000, 1),
('payment:create', '发起支付',   'payment', 'create', 'trade', 32050, 1),
('payment:update', '更新支付',   'payment', 'update', 'trade', 32100, 1),

('refund:read',   '查看退款',   'refund', 'read',   'trade', 32500, 1),
('refund:create', '申请退款',   'refund', 'create', 'trade', 32550, 1),
('refund:update', '处理退款',   'refund', 'update', 'trade', 32600, 1),

('delivery:read',   '查看物流',   'delivery', 'read',   'trade', 33000, 1),
('delivery:create', '创建发货',   'delivery', 'create', 'trade', 33050, 1),
('delivery:update', '编辑物流',   'delivery', 'update', 'trade', 33100, 1);

-- marketing 模块 (40000-49999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('promotion:read',   '查看促销',   'promotion', 'read',   'marketing', 41000, 1),
('promotion:create', '创建促销',   'promotion', 'create', 'marketing', 41050, 1),
('promotion:update', '编辑促销',   'promotion', 'update', 'marketing', 41100, 1),
('promotion:delete', '删除促销',   'promotion', 'delete', 'marketing', 41150, 1);

-- merchant 模块 (45000-49999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('merchant:read',            '查看商家',       'merchant',          'read',    'merchant', 45100, 1),
('merchant:create',          '创建商家',       'merchant',          'create',  'merchant', 45150, 1),
('merchant:update',          '编辑商家',       'merchant',          'update',  'merchant', 45200, 1),
('merchant:delete',          '删除商家',       'merchant',          'delete',  'merchant', 45250, 1),

('merchant_bank:read',       '查看银行账户',   'merchant_bank',     'read',    'merchant', 46000, 1),
('merchant_bank:create',     '添加银行账户',   'merchant_bank',     'create',  'merchant', 46050, 1),
('merchant_bank:update',     '编辑银行账户',   'merchant_bank',     'update',  'merchant', 46100, 1),
('merchant_bank:delete',     '删除银行账户',   'merchant_bank',     'delete',  'merchant', 46150, 1),

('merchant_contact:read',    '查看联系人',     'merchant_contact',  'read',    'merchant', 47000, 1),
('merchant_contact:create',  '添加联系人',     'merchant_contact',  'create',  'merchant', 47050, 1),
('merchant_contact:update',  '编辑联系人',     'merchant_contact',  'update',  'merchant', 47100, 1),
('merchant_contact:delete',  '删除联系人',     'merchant_contact',  'delete',  'merchant', 47150, 1),

('merchant_qual:read',       '查看资质',       'merchant_qual',     'read',    'merchant', 48000, 1),
('merchant_qual:create',     '上传资质',       'merchant_qual',     'create',  'merchant', 48050, 1),
('merchant_qual:update',     '编辑资质',       'merchant_qual',     'update',  'merchant', 48100, 1),
('merchant_qual:delete',     '删除资质',       'merchant_qual',     'delete',  'merchant', 48150, 1),
('merchant_qual:audit',      '审核资质',       'merchant_qual',     'audit',   'merchant', 48200, 1),

('merchant_withdraw:read',   '查看提现',       'merchant_withdraw', 'read',    'merchant', 49000, 1),
('merchant_withdraw:approve','审核通过提现',   'merchant_withdraw', 'approve', 'merchant', 49050, 1),
('merchant_withdraw:reject', '拒绝提现',       'merchant_withdraw', 'reject',  'merchant', 49100, 1),

('merchant_balance:read',    '查看余额',       'merchant_balance',  'read',    'merchant', 49500, 1);

-- review 模块 (50000-59999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('review:read',     '查看评论',   'review', 'read',     'review', 51000, 1),
('review:create',   '发表评论',   'review', 'create',   'review', 51050, 1),
('review:moderate', '审核评论',   'review', 'moderate', 'review', 51100, 1),
('review:reply',    '回复评论',   'review', 'reply',    'review', 51150, 1),
('review:delete',   '删除评论',   'review', 'delete',   'review', 51200, 1);

-- staff 模块 (60000-69999) — 角色 & 权限管理

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('role:read',     '查看角色',   'role',       'read',   'staff', 61000, 1),
('role:create',   '创建角色',   'role',       'create', 'staff', 61050, 1),
('role:update',   '编辑角色',   'role',       'update', 'staff', 61100, 1),
('role:delete',   '删除角色',   'role',       'delete', 'staff', 61150, 1),

('permission:read',   '查看权限',   'permission', 'read',   'staff', 61500, 1),
('permission:create', '创建权限',   'permission', 'create', 'staff', 61550, 1),
('permission:update', '编辑权限',   'permission', 'update', 'staff', 61600, 1),
('permission:delete', '删除权限',   'permission', 'delete', 'staff', 61650, 1);

-- user 模块 (70000-79999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('user:read',     '查看用户',   'user',    'read',   'user', 71000, 1),
('user:create',   '创建用户',   'user',    'create', 'user', 71050, 1),
('user:update',   '编辑用户',   'user',    'update', 'user', 71100, 1),
('user:delete',   '删除用户',   'user',    'delete', 'user', 71150, 1),

('address:read',   '查看地址',   'address', 'read',   'user', 71500, 1),
('address:create', '创建地址',   'address', 'create', 'user', 71550, 1),
('address:update', '编辑地址',   'address', 'update', 'user', 71600, 1),
('address:delete', '删除地址',   'address', 'delete', 'user', 71650, 1),

('points:read', '查看积分', 'points', 'read', 'user', 72000, 1),
('level:read',  '查看等级', 'level',  'read', 'user', 72050, 1);

-- base 模块 (80000-89999) — 通知

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('notification:read',   '查看通知',   'notification', 'read',   'base', 81000, 1),
('notification:create', '发送通知',   'notification', 'create', 'base', 81050, 1),
('notification:update', '标记已读',   'notification', 'update', 'base', 81100, 1),
('notification:delete', '删除通知',   'notification', 'delete', 'base', 81150, 1);

-- dashboard 模块 (90000-99999)

INSERT INTO sys_permissions (name, display_name, resource, action, category, sort_order, status) VALUES
('dashboard:read', '查看仪表盘', 'dashboard', 'read', 'dashboard', 91000, 1);


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
    'notification:read', 'notification:update',
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
    'merchant:read',
    'merchant_bank:read', 'merchant_bank:create', 'merchant_bank:update', 'merchant_bank:delete',
    'merchant_contact:read', 'merchant_contact:create', 'merchant_contact:update', 'merchant_contact:delete',
    'merchant_qual:read', 'merchant_qual:create', 'merchant_qual:update', 'merchant_qual:delete',
    'merchant_withdraw:read', 'merchant_withdraw:approve', 'merchant_withdraw:reject',
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
