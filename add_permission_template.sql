-- ============================================================================
-- 新增权限 SQL 模板（增量脚本，不清理现有数据）
--
-- 适用场景：
--   1. 往已有模块中插入新操作（如 coupon:export）
--   2. 在模块末尾追加操作（如 promotion:approve）
--   3. 在两大模块之间插入一个全新模块（如分销管理）
--   4. 在大类末尾追加一个全新模块（如客服工单）
--
-- 用法：
--   - 找到目标位置附近现有权限的 sort 值
--   - 按排序规则计算新 sort（操作间 50 间隔，模块间 500 间隔）
--   - 按需为角色分配新权限
-- ============================================================================
-- 【参考：现有 sort 分布】
--   大类一 商品库存    10000-19999
--     商品管理         11000-11150
--     分类管理         11500-11650
--     库存管理         12000-12150
--     SKU 管理         12500-12650
--     规格属性管理     13000-13400
--   大类二 交易订单    20000-29999
--     订单管理         21000-21200
--     购物车管理       21500-21650
--     支付管理         22000-22100
--     退款管理         22500-22600
--     秒杀管理         23000-23250
--     优惠券管理       23500-23700
--     促销管理         24000-24150
--      ← 24500 后可插入新模块（如销售/分销）
--   大类三 评价反馈    30000-39999
--     评论管理         31000-31150
--      ← 31500 后可插入新模块
--   大类四 用户与系统  40000-49999
--     通知管理         41000-41150
--     用户管理         41500-41650
--     权限管理         42000-42150
-- ============================================================================

USE eshop_db;

-- ========================================================================
-- 场景一：往已有模块中插入新操作
-- 示例：在 coupon:delete(23650) 和 coupon:claim(23700) 之间加 coupon:export
-- 新 sort = 23650 + 25 = 23675（取前后两个 sort 的中间值）
-- ========================================================================

-- INSERT INTO usr_permissions (name, display_name, description, resource, action, category, sort, status) VALUES
-- ('coupon:export', '导出优惠券', '导出优惠券数据报表', 'coupon', 'export', '优惠券管理', 23675, 1);
--
-- -- 为角色分配新权限（按需组合）
-- INSERT INTO usr_role_permissions (role_id, permission_id)
-- SELECT r.id, p.id FROM usr_roles r, usr_permissions p
-- WHERE r.name IN ('admin', 'editor') AND p.name = 'coupon:export';


-- ========================================================================
-- 场景二：在已有模块末尾追加操作
-- 示例：秒杀管理最后一个是 flash:manage(23250)，追加 flash:export
-- 新 sort = 23250 + 50 = 23300（模块基准 23000 + 已有操作数量 × 50 + 50）
-- ========================================================================

-- INSERT INTO usr_permissions (name, display_name, description, resource, action, category, sort, status) VALUES
-- ('flash:export', '导出秒杀数据', '导出秒杀活动数据报表', 'flash', 'export', '秒杀管理', 23300, 1);
--
-- INSERT INTO usr_role_permissions (role_id, permission_id)
-- SELECT r.id, p.id FROM usr_roles r, usr_permissions p
-- WHERE r.name IN ('admin', 'operator') AND p.name = 'flash:export';


-- ========================================================================
-- 场景三：在两大模块之间插入一个全新模块
--
-- 【情形 A】模块间有空位（500 间隔内直接放）
-- 示例：在订单管理(21000)和购物车管理(21500)之间加「售后管理」
-- 新模块基准 = 21000 + 250 = 21250
-- ========================================================================

-- INSERT INTO usr_permissions (name, display_name, description, resource, action, category, sort, status) VALUES
-- ('aftersale:read',   '查看售后',   '查看售后工单列表和详情',   'aftersale', 'read',   '售后管理', 21250, 1),
-- ('aftersale:create', '创建工单',   '创建售后工单',             'aftersale', 'create', '售后管理', 21275, 1),
-- ('aftersale:update', '处理工单',   '处理售后工单',             'aftersale', 'update', '售后管理', 21300, 1);
--
-- -- 为角色分配新权限
-- INSERT INTO usr_role_permissions (role_id, permission_id)
-- SELECT r.id, p.id FROM usr_roles r, usr_permissions p
-- WHERE r.name IN ('admin', 'operator') AND p.name LIKE 'aftersale:%';


-- ========================================================================
-- 【情形 B】模块间无空位 → 先用偏移腾空间
-- 示例：在促销管理(24000)之后、大类三(30000)之前插入「销售管理」
-- 但 24000 + 500 = 24500 → 30000 之间还有 5500 空间，直接放即可
-- ========================================================================

-- INSERT INTO usr_permissions (name, display_name, description, resource, action, category, sort, status) VALUES
-- ('sales:read',   '查看销售',   '查看销售数据',         'sales', 'read',   '销售管理', 25000, 1),
-- ('sales:export', '导出销售',   '导出销售数据报表',     'sales', 'export', '销售管理', 25050, 1);
--
-- INSERT INTO usr_role_permissions (role_id, permission_id)
-- SELECT r.id, p.id FROM usr_roles r, usr_permissions p
-- WHERE r.name IN ('admin', 'finance') AND p.name LIKE 'sales:%';


-- ========================================================================
-- 【情形 C】目标区间已被占满 → 先偏移后插入
-- 示例：想在订单管理(21000)之后加一个模块，但 21000~21500 之间已无空位
-- 步骤：将购物车管理(21500)及之后所有模块整体后移 500
-- ========================================================================

-- -- 第 1 步：偏移（将目标位置后的所有模块后移）
-- UPDATE usr_permissions SET sort = sort + 500
-- WHERE sort >= 21500;
--
-- -- 第 2 步：验证无冲突
-- SELECT sort, name FROM usr_permissions ORDER BY sort;
--
-- -- 第 3 步：插入新模块（基准 = 21500 - 500 = 21000 + 原有模块长度）
-- INSERT INTO usr_permissions (name, display_name, description, resource, action, category, sort, status) VALUES
-- ('subscribe:read',   '查看订阅',   '查看订阅列表',         'subscribe', 'read',   '订阅管理', 21250, 1),
-- ('subscribe:create', '创建订阅',   '创建订阅',             'subscribe', 'create', '订阅管理', 21300, 1);
--
-- -- 第 4 步：分配角色权限
-- INSERT INTO usr_role_permissions (role_id, permission_id)
-- SELECT r.id, p.id FROM usr_roles r, usr_permissions p
-- WHERE r.name IN ('admin', 'user') AND p.name LIKE 'subscribe:%';


-- ========================================================================
-- 场景四：在大类末尾追加一个全新模块
-- 示例：大类三 评价反馈(30000-39999) 末尾追加「问答管理」
-- 新模块基准 = 31000 + 500 = 31500（模块占用 500 间隔）
-- ========================================================================

-- INSERT INTO usr_permissions (name, display_name, description, resource, action, category, sort, status) VALUES
-- ('faq:read',   '查看问答',   '查看问答列表',   'faq', 'read',   '问答管理', 31500, 1),
-- ('faq:create', '创建问答',   '创建问答',       'faq', 'create', '问答管理', 31550, 1),
-- ('faq:update', '编辑问答',   '编辑问答',       'faq', 'update', '问答管理', 31600, 1),
-- ('faq:delete', '删除问答',   '删除问答',       'faq', 'delete', '问答管理', 31650, 1);
--
-- INSERT INTO usr_role_permissions (role_id, permission_id)
-- SELECT r.id, p.id FROM usr_roles r, usr_permissions p
-- WHERE r.name IN ('admin', 'editor') AND p.name LIKE 'faq:%';


-- ========================================================================
-- 场景五：在已有大类末尾追加新模块
-- 示例：在第一大类 商品库存(10000-19999) 末尾追加「SKU 管理」
-- 新模块基准 = 12000 + 500 = 12500（库存管理基准 + 500 模块间隔）
-- ========================================================================

-- INSERT INTO usr_permissions (name, display_name, description, resource, action, category, sort, status) VALUES
-- ('sku:read',   '查看 SKU',   '查看 SKU 列表和详情',            'sku', 'read',   'SKU 管理', 12500, 1),
-- ('sku:create', '创建 SKU',   '创建新的 SKU（含批量创建）',      'sku', 'create', 'SKU 管理', 12550, 1),
-- ('sku:update', '编辑 SKU',   '更新 SKU 价格/编码/图片等信息',   'sku', 'update', 'SKU 管理', 12600, 1),
-- ('sku:delete', '删除 SKU',   '删除 SKU',                       'sku', 'delete', 'SKU 管理', 12650, 1);
--
-- -- 为角色分配 SKU 权限
-- INSERT INTO usr_role_permissions (role_id, permission_id)
-- SELECT r.id, p.id FROM usr_roles r, usr_permissions p
-- WHERE r.name IN ('admin', 'editor', 'operator') AND p.name LIKE 'sku:%';


-- ========================================================================
-- 场景六：在第一大类末尾追加「规格属性管理」模块
-- 示例：在 SKU 管理(12500-12650) 之后追加规格属性管理
-- 新模块基准 = 12500 + 500 = 13000
-- ========================================================================

-- INSERT INTO usr_permissions (name, display_name, description, resource, action, category, sort, status) VALUES
-- ('attr:read',   '查看属性维度', '查看规格属性维度列表和详情', 'attr', 'read',   '规格属性管理', 13000, 1),
-- ('attr:create', '创建属性维度', '创建新的规格属性维度',       'attr', 'create', '规格属性管理', 13050, 1),
-- ('attr:update', '编辑属性维度', '更新规格属性维度信息',       'attr', 'update', '规格属性管理', 13100, 1),
-- ('attr:delete', '删除属性维度', '删除规格属性维度',           'attr', 'delete', '规格属性管理', 13150, 1);
--
-- INSERT INTO usr_permissions (name, display_name, description, resource, action, category, sort, status) VALUES
-- ('attr_val:read',   '查看属性值', '查看属性可选值列表',     'attr_val', 'read',   '规格属性管理', 13250, 1),
-- ('attr_val:create', '创建属性值', '为属性维度创建可选值',   'attr_val', 'create', '规格属性管理', 13300, 1),
-- ('attr_val:update', '编辑属性值', '更新属性可选值信息',     'attr_val', 'update', '规格属性管理', 13350, 1),
-- ('attr_val:delete', '删除属性值', '删除属性可选值',         'attr_val', 'delete', '规格属性管理', 13400, 1);
--
-- INSERT INTO usr_role_permissions (role_id, permission_id)
-- SELECT r.id, p.id FROM usr_roles r, usr_permissions p
-- WHERE r.name = 'admin' AND p.name IN ('attr:read','attr:create','attr:update','attr:delete','attr_val:read','attr_val:create','attr_val:update','attr_val:delete');
--
-- INSERT INTO usr_role_permissions (role_id, permission_id)
-- SELECT r.id, p.id FROM usr_roles r, usr_permissions p
-- WHERE r.name = 'editor' AND p.name IN ('attr:read','attr_val:read');


-- ========================================================================
-- 快速参考：常用 sort 占位值速查
-- ========================================================================
--
-- 模块内插入新操作：
--   sort = 前一个操作的 sort + (后一个操作的 sort - 前一个操作的 sort) / 2
--
-- 模块间插入新模块（有空位）：
--   sort = 前一个模块基准 + 250
--
-- 模块间插入新模块（无空位）：
--   1. UPDATE permissions SET sort = sort + 500 WHERE sort >= 目标基准
--   2. 新模块基准 = 目标基准
--
-- 确认可用位置：
--   SELECT sort FROM usr_permissions ORDER BY sort;
