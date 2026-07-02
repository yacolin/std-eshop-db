USE eshop_db;

-- ============================================================
-- base_p0.sql — 通知相关独立表
-- ============================================================

CREATE TABLE `base_notification_templates` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
    `template_code` VARCHAR(50) UNIQUE NOT NULL COMMENT '模板代码（如 ORDER_PAID_SUCCESS）',
    `channel` TINYINT NOT NULL COMMENT '渠道 1-站内 2-Push 3-短信 4-邮件',
    `title_template` VARCHAR(200) NOT NULL COMMENT '标题模板（支持变量 {{.OrderID}}）',
    `content_template` TEXT NOT NULL COMMENT '内容模板',
    `category` TINYINT COMMENT '默认分类',
    `priority` TINYINT DEFAULT 1 COMMENT '默认优先级',
    `status` TINYINT DEFAULT 1 COMMENT '1-启用 0-停用',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_code_channel` (`template_code`, `channel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知模板表';


CREATE TABLE `base_notifications` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '通知ID',

    -- 接收人
    `user_id` BIGINT NOT NULL COMMENT '接收用户ID',
    `merchant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '所属商家ID（0表示平台）',

    -- 通知基本信息
    `title` VARCHAR(200) NOT NULL COMMENT '通知标题',
    `content` TEXT NOT NULL COMMENT '通知内容（最终渲染后的文本）',
    `content_template` VARCHAR(100) COMMENT '内容模板ID（用于统计/调试）',
    `template_params` JSON COMMENT '模板参数（存原始变量，便于回溯）',

    -- 通知类型（多维度分类）
    `channel` TINYINT NOT NULL COMMENT '渠道: 1-站内消息 2-App Push 3-短信 4-邮件 5-微信模板消息',
    `category` TINYINT NOT NULL COMMENT '分类: 1-系统公告 2-订单通知 3-营销推广 4-互动通知 5-安全提醒',

    -- 业务关联（用于跳转）
    `target_type` VARCHAR(30) COMMENT '关联业务类型: order/coupon/review/activity 等',
    `target_id` BIGINT COMMENT '关联业务ID',
    `redirect_url` VARCHAR(500) COMMENT '跳转链接（优先级高于 target_type+id）',

    -- 扩展图片/图标
    `icon_url` VARCHAR(500) COMMENT '通知图标（如订单图标、优惠券图标）',

    -- 状态管理
    `is_read` TINYINT DEFAULT 0 COMMENT '0-未读 1-已读',
    `read_at` DATETIME COMMENT '阅读时间',
    `is_processed` TINYINT DEFAULT 0 COMMENT '0-待处理 1-已处理（如短信已发送、Push已推送）',
    `processed_at` DATETIME COMMENT '处理时间',
    `process_result` VARCHAR(200) COMMENT '处理结果（如短信发送回执ID）',

    -- 用户操作（可选）
    `is_deleted_by_user` TINYINT DEFAULT 0 COMMENT '用户是否删除（软删除，前端不展示）',

    -- 优先级
    `priority` TINYINT DEFAULT 1 COMMENT '优先级: 0-高 1-中 2-低（用于排序展示）',

    -- 审计字段
    `created_by` BIGINT COMMENT '创建人（0表示系统自动）',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted_at` DATETIME DEFAULT NULL COMMENT '系统软删除（数据清理用）',

    -- 索引
    INDEX `idx_user_read` (`user_id`, `is_read`, `created_at` DESC),
    INDEX `idx_merchant` (`merchant_id`),
    INDEX `idx_channel` (`channel`),
    INDEX `idx_category` (`category`),
    INDEX `idx_target` (`target_type`, `target_id`),
    INDEX `idx_processed` (`is_processed`, `processed_at`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='统一通知表';
