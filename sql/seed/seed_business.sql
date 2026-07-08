-- ============================================================================
-- 业务数据初始化
-- 用户等级 → B端员工 → C端消费者 → 地址
-- ============================================================================

USE eshop_db;

-- ==================== 用户等级 ====================

INSERT INTO usr_levels (name, level, min_points, max_points, discount_rate, free_shipping, points_multiplier, benefits) VALUES
('青铜会员', 1, 0,     999,  1000, 0, 1.00, '{"birthday_gift": false}'),
('白银会员', 2, 1000,  4999, 950,  0, 1.20, '{"birthday_gift": false}'),
('黄金会员', 3, 5000,  19999, 900, 1, 1.50, '{"birthday_gift": true}'),
('钻石会员', 4, 20000, 0,     850, 1, 2.00, '{"birthday_gift": true, "exclusive_coupon": true}');

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
(1, '陈科林', '13900139002', '中国', '广东省', '广州市', '天河区', '珠江新城华夏路16号富力凯盈广场3001', '510623', 'home', FALSE);
