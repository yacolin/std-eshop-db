USE eshop_db;

-- ============================================================
-- sys_p0.sql — 系统员工域（B端后台）
-- RBAC + 员工管理，与 C端消费者域（usr_*）完全隔离
-- ============================================================

-- ==================== 角色定义 ====================

CREATE TABLE `sys_roles` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name` varchar(50) NOT NULL COMMENT '角色名称（唯一，如 admin/editor/vip）',
  `display_name` varchar(100) NOT NULL DEFAULT '' COMMENT '角色显示名称',
  `description` varchar(255) NOT NULL DEFAULT '' COMMENT '角色描述',
  `role_type` varchar(20) NOT NULL DEFAULT 'custom' COMMENT 'builtin-系统内置 custom-自定义',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序值',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1-启用 0-禁用',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_name` (`name`),
  KEY `idx_type` (`role_type`),
  KEY `idx_status` (`status`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='B端角色定义表';


CREATE TABLE `sys_permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name` varchar(100) NOT NULL COMMENT '权限标识（唯一，如 order:create）',
  `display_name` varchar(100) NOT NULL DEFAULT '' COMMENT '权限显示名称',
  `description` varchar(255) NOT NULL DEFAULT '' COMMENT '权限描述',
  `resource` varchar(50) NOT NULL COMMENT '资源（如 order/product/user）',
  `action` varchar(50) NOT NULL COMMENT '操作（如 create/read/update/delete）',
  `category` varchar(50) NOT NULL DEFAULT '' COMMENT '分类（如 business/system/admin）',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序值',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1-启用 0-禁用',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_name` (`name`),
  KEY `idx_resource` (`resource`),
  KEY `idx_action` (`action`),
  KEY `idx_status` (`status`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='B端权限表';


CREATE TABLE `sys_role_permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `role_id` bigint NOT NULL COMMENT '角色ID（关联 sys_roles.id）',
  `permission_id` bigint NOT NULL COMMENT '权限ID（关联 sys_permissions.id）',
  `scope_type` varchar(20) NOT NULL DEFAULT 'platform' COMMENT '范围：platform-平台 merchant-商家',
  `scope_id` bigint NOT NULL DEFAULT 0 COMMENT '范围ID（平台0/商家ID）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_role_permission` (`role_id`, `permission_id`) USING BTREE,
  KEY `idx_permission_id` (`permission_id`),
  KEY `idx_scope` (`scope_type`, `scope_id`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='角色-权限关联表';


-- ==================== 员工管理 ====================

CREATE TABLE `sys_staff` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `username` varchar(50) NOT NULL COMMENT '登录用户名（唯一）',
  `password_hash` varchar(255) NOT NULL DEFAULT '' COMMENT 'bcrypt 密码哈希',
  `real_name` varchar(50) NOT NULL DEFAULT '' COMMENT '真实姓名',
  `email` varchar(100) DEFAULT NULL COMMENT '邮箱',
  `phone` varchar(20) DEFAULT NULL COMMENT '手机号',
  `avatar` varchar(512) DEFAULT '' COMMENT '头像URL',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1-正常 0-禁用',
  `last_login_ip` varchar(50) DEFAULT '' COMMENT '最后登录IP',
  `last_login_at` datetime(3) DEFAULT NULL COMMENT '最后登录时间',
  `created_by` bigint DEFAULT 0 COMMENT '创建人ID（0=系统）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_username` (`username`),
  KEY `idx_status` (`status`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='B端员工表（后台管理员/运营/财务等）';


CREATE TABLE `sys_staff_roles` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `staff_id` bigint NOT NULL COMMENT '员工ID（关联 sys_staff.id）',
  `role_id` bigint NOT NULL COMMENT '角色ID（关联 sys_roles.id）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_staff_role` (`staff_id`, `role_id`) USING BTREE,
  KEY `idx_role_id` (`role_id`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='员工-角色关联表（平台级角色）';


CREATE TABLE `sys_login_histories` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `staff_id` bigint NOT NULL COMMENT '员工ID（关联 sys_staff.id）',
  `login_ip` varchar(50) NOT NULL DEFAULT '' COMMENT '登录IP',
  `login_device` varchar(100) NOT NULL DEFAULT '' COMMENT '登录设备信息（UA）',
  `login_location` varchar(100) NOT NULL DEFAULT '' COMMENT '登录地点',
  `login_method` varchar(20) NOT NULL DEFAULT '' COMMENT '登录方式：password/sms/oauth',
  `login_status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1-成功 0-失败',
  `failure_reason` varchar(100) NOT NULL DEFAULT '' COMMENT '失败原因',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_staff_id` (`staff_id`) USING BTREE,
  KEY `idx_created_at` (`created_at`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='B端员工登录历史表';
