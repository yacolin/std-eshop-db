USE eshop_db;

-- ============================================================
-- usr_p1.sql — RBAC 权限与审计表（依赖 P0: users）
-- ============================================================

CREATE TABLE `usr_roles` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '角色名称（唯一，如 admin/editor/vip）',
  `display_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '角色显示名称',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '角色描述',
  `role_type` varchar(20) NOT NULL DEFAULT 'custom' COMMENT '角色类型：builtin-系统内置 custom-自定义',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序值',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态：1-启用 0-禁用',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_name` (`name`),
  KEY `idx_type` (`role_type`),
  KEY `idx_status` (`status`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='角色表';


CREATE TABLE `usr_permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '权限标识（唯一，如 order:create）',
  `display_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '权限显示名称',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '权限描述',
  `resource` varchar(50) NOT NULL COMMENT '资源（如 order/product/user）',
  `action` varchar(50) NOT NULL COMMENT '操作（如 create/read/update/delete）',
  `category` varchar(50) NOT NULL DEFAULT '' COMMENT '分类（如 business/system/admin）',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序值',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态：1-启用 0-禁用',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_name` (`name`),
  KEY `idx_resource` (`resource`),
  KEY `idx_action` (`action`),
  KEY `idx_status` (`status`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='权限表';


CREATE TABLE `usr_user_roles` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `role_id` bigint NOT NULL COMMENT '角色ID',
  `scope_type` varchar(20) NOT NULL DEFAULT 'platform' COMMENT '权限范围：platform-平台 merchant-商家',
  `scope_id` bigint NOT NULL DEFAULT 0 COMMENT '范围ID（平台0/商家ID）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_user_role` (`user_id`, `role_id`) USING BTREE,
  KEY `idx_role_id` (`role_id`),
  KEY `idx_scope` (`scope_type`, `scope_id`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户-角色关联表';


CREATE TABLE `usr_role_permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `role_id` bigint NOT NULL COMMENT '角色ID',
  `permission_id` bigint NOT NULL COMMENT '权限ID',
  `scope_type` varchar(20) NOT NULL DEFAULT 'platform' COMMENT '权限范围：platform-平台 merchant-商家',
  `scope_id` bigint NOT NULL DEFAULT 0 COMMENT '范围ID（平台0/商家ID）',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_role_permission` (`role_id`, `permission_id`) USING BTREE,
  KEY `idx_permission_id` (`permission_id`),
  KEY `idx_scope` (`scope_type`, `scope_id`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='角色-权限关联表';


CREATE TABLE `usr_login_histories` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `login_ip` varchar(50) NOT NULL DEFAULT '' COMMENT '登录IP',
  `login_device` varchar(100) NOT NULL DEFAULT '' COMMENT '登录设备信息（UA）',
  `login_location` varchar(100) NOT NULL DEFAULT '' COMMENT '登录地点',
  `login_method` varchar(20) NOT NULL DEFAULT '' COMMENT '登录方式：password/sms/oauth',
  `login_status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '登录结果：1-成功 0-失败',
  `failure_reason` varchar(100) NOT NULL DEFAULT '' COMMENT '失败原因',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_user_id` (`user_id`) USING BTREE,
  KEY `idx_created_at` (`created_at`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户登录历史表';
