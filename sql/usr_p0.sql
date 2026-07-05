USE eshop_db;

-- ============================================================
-- usr_p0.sql — 用户域核心基础表
-- ============================================================

CREATE TABLE `usr_users` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `username` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '用户名（唯一，NULL表示未设置）',
  `password_hash` varchar(255) NOT NULL DEFAULT '' COMMENT 'bcrypt 密码哈希',
  `email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '邮箱（唯一，NULL表示未绑定）',
  `email_verified` tinyint(1) NOT NULL DEFAULT '0' COMMENT '邮箱是否已验证',
  `phone` varchar(20) DEFAULT NULL COMMENT '手机号（唯一，NULL表示未绑定）',
  `phone_verified` tinyint(1) NOT NULL DEFAULT '0' COMMENT '手机号是否已验证',
  `avatar` varchar(512) NOT NULL DEFAULT '' COMMENT '头像URL',
  `nickname` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '昵称',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态：1-正常 0-禁用 2-冻结',
  `register_ip` varchar(50) NOT NULL DEFAULT '' COMMENT '注册IP',
  `register_source` varchar(20) NOT NULL DEFAULT '' COMMENT '注册来源：web/ios/android/admin',
  `last_login_ip` varchar(50) NOT NULL DEFAULT '' COMMENT '最后登录IP',
  `last_login_at` datetime(3) DEFAULT NULL COMMENT '最后登录时间',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_username` (`username`),
  UNIQUE KEY `uk_email` (`email`),
  UNIQUE KEY `uk_phone` (`phone`),
  KEY `idx_status` (`status`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户账户主表';


CREATE TABLE `usr_infos` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `gender` tinyint(1) NOT NULL DEFAULT '0' COMMENT '性别：0-未知 1-男 2-女',
  `birthday` date DEFAULT NULL COMMENT '生日',
  `bio` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '个人简介',
  `country` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '国家',
  `province` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '省',
  `city` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '市',
  `zip_code` varchar(10) NOT NULL DEFAULT '' COMMENT '邮编',
  `language` varchar(10) NOT NULL DEFAULT 'zh-CN' COMMENT '语言',
  `timezone` varchar(32) NOT NULL DEFAULT 'Asia/Shanghai' COMMENT '时区',

  -- 等级与积分
  `level_id` bigint NOT NULL DEFAULT 0 COMMENT '当前等级ID（关联 usr_levels.id）',
  `total_points` bigint NOT NULL DEFAULT 0 COMMENT '累计积分',

  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_user_id` (`user_id`) USING BTREE,
  CONSTRAINT `fk_usr_infos_user` FOREIGN KEY (`user_id`) REFERENCES `usr_users` (`id`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户扩展信息表';


CREATE TABLE `usr_addresses` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `consignee` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '收货人姓名',
  `phone` varchar(20) NOT NULL DEFAULT '' COMMENT '联系电话',
  `country` varchar(32) NOT NULL DEFAULT '' COMMENT '国家',
  `province` varchar(32) NOT NULL DEFAULT '' COMMENT '省',
  `city` varchar(32) NOT NULL DEFAULT '' COMMENT '市',
  `district` varchar(32) NOT NULL DEFAULT '' COMMENT '区/县',
  `detail` varchar(256) NOT NULL DEFAULT '' COMMENT '详细地址',
  `zip_code` varchar(10) NOT NULL DEFAULT '' COMMENT '邮编',
  `tag` varchar(16) NOT NULL DEFAULT '' COMMENT '地址标签：home/office/company/other',
  `is_default` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否默认地址',
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_user_id` (`user_id`) USING BTREE,
  CONSTRAINT `fk_usr_addresses_user` FOREIGN KEY (`user_id`) REFERENCES `usr_users` (`id`),
  KEY `idx_deleted_at` (`deleted_at`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户收货地址';


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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='C端消费者登录历史表';
