USE eshop_db;

-- ============================================================
-- rev_p1.sql — 评价关联表（依赖 P0: reviews）
-- ============================================================

CREATE TABLE `rev_review_media` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '媒体ID',
    `review_id` BIGINT NOT NULL COMMENT '关联评价ID',
    `media_type` TINYINT DEFAULT 1 COMMENT '1-图片 2-视频',
    `media_url` VARCHAR(500) NOT NULL COMMENT '媒体文件URL',
    `file_size` INT DEFAULT 0 COMMENT '文件大小（字节）',
    `width` INT DEFAULT 0 COMMENT '宽度（图片/视频）',
    `height` INT DEFAULT 0 COMMENT '高度（图片/视频）',
    `duration` INT DEFAULT 0 COMMENT '时长（视频，秒）',
    `sort_order` INT DEFAULT 0 COMMENT '排序',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (`id`),
    KEY `idx_review_sort` (`review_id`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价媒体表';


CREATE TABLE `rev_review_replies` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '回复ID',
    `review_id` BIGINT NOT NULL COMMENT '关联评价ID',
    `root_reply_id` BIGINT DEFAULT NULL COMMENT '根回复ID（一级回复为NULL）',
    `parent_id` BIGINT DEFAULT NULL COMMENT '父级回复ID（支持二级回复）',
    `reply_type` TINYINT DEFAULT 1 COMMENT '1-商家回复 2-用户追问 3-平台回复',
    `content` TEXT NOT NULL COMMENT '回复内容',
    `operator_id` BIGINT DEFAULT NULL COMMENT '操作人ID',
    `operator_name` VARCHAR(50) DEFAULT '' COMMENT '操作人名称（冗余，避免JOIN用户表）',
    `status` TINYINT DEFAULT 1 COMMENT '1-正常 2-隐藏 3-删除',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (`id`),
    KEY `idx_review_root` (`review_id`, `root_reply_id`, `created_at`),
    KEY `idx_parent` (`parent_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价回复表（支持二级回复）';


CREATE TABLE `rev_review_audit_logs` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    `review_id` BIGINT NOT NULL COMMENT '评价ID',
    `action` VARCHAR(30) NOT NULL COMMENT '操作：submit/approve/reject/delete/shield',
    `operator_id` BIGINT DEFAULT NULL COMMENT '操作人ID',
    `operator_name` VARCHAR(50) DEFAULT '' COMMENT '操作人名称',
    `before_status` TINYINT DEFAULT NULL COMMENT '变更前状态',
    `after_status` TINYINT DEFAULT NULL COMMENT '变更后状态',
    `remark` VARCHAR(200) DEFAULT NULL COMMENT '操作备注',
    `snapshot` JSON DEFAULT NULL COMMENT '评价快照（用于回溯）',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (`id`),
    KEY `idx_review_created` (`review_id`, `created_at`),
    KEY `idx_operator_created` (`operator_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价审核日志表';


CREATE TABLE `rev_review_statistics` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `target_type` TINYINT NOT NULL COMMENT '统计目标类型 1-SPU 2-商家',
    `target_id` BIGINT NOT NULL COMMENT '目标ID（SPU_ID或Merchant_ID）',

    `rating_1_count` INT DEFAULT 0 COMMENT '1星数量',
    `rating_2_count` INT DEFAULT 0 COMMENT '2星数量',
    `rating_3_count` INT DEFAULT 0 COMMENT '3星数量',
    `rating_4_count` INT DEFAULT 0 COMMENT '4星数量',
    `rating_5_count` INT DEFAULT 0 COMMENT '5星数量',

    `total_count` INT DEFAULT 0 COMMENT '总评价数',
    `avg_rating` DECIMAL(3,2) DEFAULT 0.00 COMMENT '平均评分',
    `good_rate` DECIMAL(5,2) DEFAULT 0.00 COMMENT '好评率（%）',

    `has_media_count` INT DEFAULT 0 COMMENT '带图评价数',
    `has_content_count` INT DEFAULT 0 COMMENT '有内容评价数',

    `last_updated_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_target` (`target_type`, `target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价统计表（T+1或实时增量更新）';


CREATE TABLE `rev_review_usefulness` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    `review_id` BIGINT NOT NULL COMMENT '评价ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `created_at` DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_review_user` (`review_id`, `user_id`),
    KEY `idx_review` (`review_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价有用记录表（用于防刷和计数）';