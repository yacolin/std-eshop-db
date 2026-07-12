-- ============================================================
-- 03_partitions.sql — 分区表月度子表创建
-- 为所有按 RANGE 分区的日志/流水表创建初始分区
-- 生产环境建议使用 pg_partman 自动管理
-- ============================================================

-- 分区维护函数：动态创建缺失的月度分区
CREATE OR REPLACE FUNCTION create_monthly_partitions(
    p_table_name text,
    p_start_date date DEFAULT CURRENT_DATE,
    p_months_ahead int DEFAULT 3
)
RETURNS void AS $$
DECLARE
    v_part_name text;
    v_start date;
    v_end date;
    v_sql text;
    v_exists boolean;
BEGIN
    FOR i IN 0..p_months_ahead LOOP
        v_start := date_trunc('month', p_start_date)::date + (i || ' months')::interval;
        v_end := v_start + interval '1 month';
        v_part_name := p_table_name || '_' || to_char(v_start, 'YYYYMM');

        -- 检查分区是否已存在
        SELECT EXISTS (
            SELECT 1 FROM pg_class WHERE relname = v_part_name
        ) INTO v_exists;

        IF NOT v_exists THEN
            v_sql := format(
                'CREATE TABLE %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
                v_part_name, p_table_name, v_start, v_end
            );
            EXECUTE v_sql;
            RAISE NOTICE 'Created partition: %', v_part_name;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ==================== 创建初始分区 ====================
-- 当前月份为 2026-07，预创建至 2026-10

SELECT create_monthly_partitions('usr_login_histories',    '2026-07-01', 3);
SELECT create_monthly_partitions('sys_login_histories',    '2026-07-01', 3);
SELECT create_monthly_partitions('sys_operation_logs',     '2026-07-01', 3);
SELECT create_monthly_partitions('tx_order_logs',          '2026-07-01', 3);
SELECT create_monthly_partitions('tx_payment_logs',        '2026-07-01', 3);
SELECT create_monthly_partitions('sp_inventory_logs',      '2026-07-01', 3);

COMMENT ON FUNCTION create_monthly_partitions IS '动态创建月度分区表';
