USE eshop_db;

-- ============================================================
-- rev_p1.sql — 评价关联表（依赖 P0: reviews）
-- ============================================================

CREATE TABLE `rev_review_media` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '媒体ID',
    `review_id` BIGINT NOT NULL COMMENT '关联评价ID',
    `media_type` TINYINT DEFAULT 1 COMMENT '1-图片 2-视频',
    `media_url` VARCHAR(500) NOT NULL COMMENT '媒体文件URL',
    `sort_order` INT DEFAULT 0 COMMENT '排序',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_review` (`review_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价媒体表';


CREATE TABLE `rev_review_replies` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '回复ID',
    `review_id` BIGINT NOT NULL COMMENT '关联评价ID',
    `parent_id` BIGINT DEFAULT NULL COMMENT '父级回复ID（支持多级回复）',
    `reply_type` TINYINT DEFAULT 1 COMMENT '1-商家回复 2-用户追问 3-平台回复',
    `content` TEXT NOT NULL COMMENT '回复内容',
    `operator_id` BIGINT COMMENT '操作人ID',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `deleted_at` DATETIME DEFAULT NULL,
    INDEX `idx_review` (`review_id`),
    INDEX `idx_parent` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价回复表';


CREATE TABLE `rev_review_ratings` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `review_id` BIGINT NOT NULL COMMENT '关联评价ID',
    `rating_type` VARCHAR(30) NOT NULL COMMENT '评分维度：overall/quality/logistics/service',
    `rating_value` TINYINT NOT NULL COMMENT '评分值（1-5）',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_review_type` (`review_id`, `rating_type`),
    INDEX `idx_type_value` (`rating_type`, `rating_value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价评分明细表';


CREATE TABLE `rev_review_audit_logs` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    `review_id` BIGINT NOT NULL COMMENT '评价ID',
    `action` VARCHAR(30) NOT NULL COMMENT '操作：submit/approve/reject/delete',
    `operator_id` BIGINT COMMENT '操作人ID',
    `remark` VARCHAR(200) COMMENT '操作备注',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_review` (`review_id`),
    INDEX `idx_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价审核日志表';
