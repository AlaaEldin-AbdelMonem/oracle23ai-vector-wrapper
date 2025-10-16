-- ============================================================================
-- PM Copilot - AI Model Metadata Tables
-- ============================================================================
-- Schema: AI
-- Purpose: Support centralized AI model management and monitoring
-- Version: 1.0
-- Date: October 15, 2025
-- ============================================================================

-- ============================================================================
-- 1. MODEL REGISTRY
-- ============================================================================

CREATE TABLE ai_model_registry (
    model_id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_name          VARCHAR2(100) NOT NULL UNIQUE,
    model_type          VARCHAR2(50) NOT NULL,
    mining_function     VARCHAR2(50),
    vector_dimensions   NUMBER,
    model_version       VARCHAR2(50),
    model_source        VARCHAR2(500),
    model_file_path     VARCHAR2(500),
    is_active           CHAR(1) DEFAULT 'Y' NOT NULL,
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    created_by          VARCHAR2(100) DEFAULT USER,
    last_used_date      TIMESTAMP,
    usage_count         NUMBER DEFAULT 0,
    avg_latency_ms      NUMBER,
    model_metadata      JSON,
    CONSTRAINT chk_model_active CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT chk_model_type CHECK (model_type IN ('ONNX', 'PRETRAINED', 'CUSTOM', 'FINE_TUNED'))
);

COMMENT ON TABLE ai_model_registry IS 'Registry of all AI models available in the system';
COMMENT ON COLUMN ai_model_registry.model_name IS 'Unique model name (matches mining model name)';
COMMENT ON COLUMN ai_model_registry.vector_dimensions IS 'Dimension of output vectors (e.g., 384, 768, 1536)';
COMMENT ON COLUMN ai_model_registry.is_active IS 'Y=Active and available, N=Inactive';
COMMENT ON COLUMN ai_model_registry.model_metadata IS 'JSON metadata about model capabilities';

CREATE INDEX idx_model_active ON ai_model_registry(is_active, model_name);
CREATE INDEX idx_model_type ON ai_model_registry(model_type);

-- ============================================================================
-- 2. USAGE LOGGING
-- ============================================================================

CREATE TABLE ai_usage_log (
    log_id              NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id          VARCHAR2(100),
    calling_schema      VARCHAR2(100) NOT NULL,
    calling_user        VARCHAR2(100),
    model_name          VARCHAR2(100) NOT NULL,
    operation_type      VARCHAR2(50) NOT NULL,
    input_text_length   NUMBER,
    batch_size          NUMBER,
    execution_time_ms   NUMBER,
    tokens_processed    NUMBER,
    success_flag        CHAR(1) NOT NULL,
    error_message       VARCHAR2(4000),
    log_timestamp       TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT chk_usage_success CHECK (success_flag IN ('Y', 'N')),
    CONSTRAINT chk_operation_type CHECK (operation_type IN (
        'EMBED_SINGLE', 'EMBED_BATCH', 'SIMILARITY', 'SEMANTIC_SEARCH', 
        'HEALTH_CHECK', 'OTHER'
    ))
);

COMMENT ON TABLE ai_usage_log IS 'Detailed log of all AI model API calls';
COMMENT ON COLUMN ai_usage_log.calling_schema IS 'Schema that made the call';
COMMENT ON COLUMN ai_usage_log.operation_type IS 'Type of operation performed';
COMMENT ON COLUMN ai_usage_log.tokens_processed IS 'Approximate number of tokens processed';

CREATE INDEX idx_usage_schema_date ON ai_usage_log(calling_schema, log_timestamp);
CREATE INDEX idx_usage_model_date ON ai_usage_log(model_name, log_timestamp);
CREATE INDEX idx_usage_operation ON ai_usage_log(operation_type, log_timestamp);
CREATE INDEX idx_usage_success ON ai_usage_log(success_flag, log_timestamp);

-- ============================================================================
-- 3. PERFORMANCE METRICS (Aggregated)
-- ============================================================================

CREATE TABLE ai_performance_metrics (
    metric_id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_name          VARCHAR2(100) NOT NULL,
    metric_date         DATE NOT NULL,
    total_calls         NUMBER DEFAULT 0,
    successful_calls    NUMBER DEFAULT 0,
    failed_calls        NUMBER DEFAULT 0,
    avg_latency_ms      NUMBER,
    min_latency_ms      NUMBER,
    max_latency_ms      NUMBER,
    p95_latency_ms      NUMBER,
    p99_latency_ms      NUMBER,
    total_tokens        NUMBER,
    total_execution_ms  NUMBER,
    unique_schemas      NUMBER,
    unique_users        NUMBER,
    CONSTRAINT uk_perf_model_date UNIQUE (model_name, metric_date)
);

COMMENT ON TABLE ai_performance_metrics IS 'Daily aggregated performance metrics per model';
COMMENT ON COLUMN ai_performance_metrics.p95_latency_ms IS '95th percentile latency';
COMMENT ON COLUMN ai_performance_metrics.p99_latency_ms IS '99th percentile latency';

CREATE INDEX idx_perf_date ON ai_performance_metrics(metric_date DESC);
CREATE INDEX idx_perf_model ON ai_performance_metrics(model_name, metric_date DESC);

-- ============================================================================
-- 4. MODEL CONFIGURATION
-- ============================================================================

CREATE TABLE ai_model_config (
    config_id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_name          VARCHAR2(100) NOT NULL,
    config_key          VARCHAR2(100) NOT NULL,
    config_value        VARCHAR2(4000),
    config_type         VARCHAR2(50) DEFAULT 'STRING',
    description         VARCHAR2(500),
    is_active           CHAR(1) DEFAULT 'Y',
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_by          VARCHAR2(100) DEFAULT USER,
    CONSTRAINT uk_model_config UNIQUE (model_name, config_key),
    CONSTRAINT chk_config_active CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT chk_config_type CHECK (config_type IN (
        'STRING', 'NUMBER', 'BOOLEAN', 'JSON', 'ARRAY'
    ))
);

COMMENT ON TABLE ai_model_config IS 'Configuration parameters for AI models';
COMMENT ON COLUMN ai_model_config.config_key IS 'Configuration parameter name';
COMMENT ON COLUMN ai_model_config.config_type IS 'Data type of the configuration value';

CREATE INDEX idx_config_model ON ai_model_config(model_name, is_active);

-- ============================================================================
-- 5. VIEWS FOR MONITORING
-- ============================================================================

-- Model registry with usage stats
CREATE OR REPLACE VIEW ai_model_registry_v AS
SELECT --'Model registry with recent usage statistics'
    r.model_id,
    r.model_name,
    r.model_type,
    r.mining_function,
    r.vector_dimensions,
    r.model_version,
    r.is_active,
    r.created_date,
    r.last_used_date,
    r.usage_count,
    r.avg_latency_ms,
    -- Recent stats (last 24 hours)
    COUNT(l.log_id) AS calls_last_24h,
    SUM(CASE WHEN l.success_flag = 'Y' THEN 1 ELSE 0 END) AS success_last_24h,
    SUM(CASE WHEN l.success_flag = 'N' THEN 1 ELSE 0 END) AS errors_last_24h
FROM ai_model_registry r
LEFT JOIN ai_usage_log l 
    ON r.model_name = l.model_name 
    AND l.log_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
GROUP BY 
    r.model_id, r.model_name, r.model_type, r.mining_function,
    r.vector_dimensions, r.model_version, r.is_active, r.created_date,
    r.last_used_date, r.usage_count, r.avg_latency_ms;

 
-- Daily usage summary by schema
CREATE OR REPLACE VIEW ai_daily_usage_by_schema_v AS
SELECT --'Daily usage statistics grouped by schema and operation'
    calling_schema,
    TRUNC(log_timestamp) AS usage_date,
    model_name,
    operation_type,
    COUNT(*) AS total_calls,
    SUM(CASE WHEN success_flag = 'Y' THEN 1 ELSE 0 END) AS successful_calls,
    SUM(CASE WHEN success_flag = 'N' THEN 1 ELSE 0 END) AS failed_calls,
    ROUND(AVG(execution_time_ms), 2) AS avg_latency_ms,
    ROUND(MIN(execution_time_ms), 2) AS min_latency_ms,
    ROUND(MAX(execution_time_ms), 2) AS max_latency_ms,
    SUM(tokens_processed) AS total_tokens,
    SUM(CASE WHEN batch_size IS NOT NULL THEN batch_size ELSE 1 END) AS total_items
FROM ai_usage_log
GROUP BY calling_schema, TRUNC(log_timestamp), model_name, operation_type;

 
 
-- Real-time usage (last hour)
-- Real-time usage statistics for the last hour
CREATE OR REPLACE VIEW ai_realtime_usage_v AS
SELECT  ---- Real-time usage (last hour)
  calling_schema,
  model_name,
  operation_type,
  COUNT(*) AS calls ,
  SUM(CASE WHEN success_flag = 'Y' THEN 1 ELSE 0 END) AS successfulx,
  SUM(CASE WHEN success_flag = 'N' THEN 1 ELSE 0 END) AS failed,
  ROUND(AVG(execution_time_ms), 2) AS avg_latency_ms,
  MAX(log_timestamp) AS last_call_time
FROM ai_usage_log
WHERE log_timestamp > SYSTIMESTAMP - INTERVAL '1' HOUR
GROUP BY calling_schema, model_name, operation_type;


 
-- Error summary
CREATE OR REPLACE VIEW ai_error_summary_v AS
SELECT --'Summary of errors in the last 7 days'
    calling_schema,
    model_name,
    operation_type,
    error_message,
    COUNT(*) AS error_count,
    MIN(log_timestamp) AS first_occurrence,
    MAX(log_timestamp) AS last_occurrence
FROM ai_usage_log
WHERE success_flag = 'N'
  AND log_timestamp > SYSTIMESTAMP - INTERVAL '7' DAY
GROUP BY calling_schema, model_name, operation_type, error_message
ORDER BY error_count DESC;

 

-- Model health dashboard
CREATE OR REPLACE VIEW ai_model_health_v AS
SELECT --'Model health status with alerts'
    m.model_name,
    m.is_active,
    m.last_used_date,
    m.avg_latency_ms AS historical_avg_latency,
    COUNT(l.log_id) AS calls_last_24h,
    SUM(CASE WHEN l.success_flag = 'Y' THEN 1 ELSE 0 END) AS success_last_24h,
    SUM(CASE WHEN l.success_flag = 'N' THEN 1 ELSE 0 END) AS errors_last_24h,
    ROUND(AVG(l.execution_time_ms), 2) AS current_avg_latency,
    CASE 
        WHEN COUNT(l.log_id) = 0 THEN 'IDLE'
        WHEN SUM(CASE WHEN l.success_flag = 'N' THEN 1 ELSE 0 END) > 
             COUNT(l.log_id) * 0.1 THEN 'DEGRADED'
        WHEN AVG(l.execution_time_ms) > m.avg_latency_ms * 2 THEN 'SLOW'
        ELSE 'HEALTHY'
    END AS health_status
FROM ai_model_registry m
LEFT JOIN ai_usage_log l 
    ON m.model_name = l.model_name 
    AND l.log_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
GROUP BY m.model_name, m.is_active, m.last_used_date, m.avg_latency_ms;

 

-- ============================================================================
-- 6. INITIAL DATA LOAD
-- ============================================================================

-- Register the MiniLM model
MERGE INTO ai_model_registry r
USING (
    SELECT 
        'ALL_MINILM_L12_V2' AS model_name,
        'ONNX' AS model_type,
        'EMBEDDING' AS mining_function,
        384 AS vector_dimensions,
        'v2' AS model_version,
        'sentence-transformers/all-MiniLM-L12-v2' AS model_source,
        'ONNX_DIR/all_MiniLM_L12_v2.onnx' AS model_file_path
    FROM dual
) s
ON (r.model_name = s.model_name)
WHEN MATCHED THEN
    UPDATE SET 
        r.model_type = s.model_type,
        r.vector_dimensions = s.vector_dimensions,
        r.model_version = s.model_version,
        r.is_active = 'Y'
WHEN NOT MATCHED THEN
    INSERT (
        model_name, model_type, mining_function, vector_dimensions,
        model_version, model_source, model_file_path, is_active
    ) VALUES (
        s.model_name, s.model_type, s.mining_function, s.vector_dimensions,
        s.model_version, s.model_source, s.model_file_path, 'Y'
    );

-- Add default configuration
MERGE INTO ai_model_config c
USING (
    SELECT 'ALL_MINILM_L12_V2' AS model_name, 'max_tokens' AS config_key, '8000' AS config_value, 'NUMBER' AS config_type, 'Maximum input tokens' AS description FROM dual UNION ALL
    SELECT 'ALL_MINILM_L12_V2', 'normalize_output', 'true', 'BOOLEAN', 'Normalize output vectors' FROM dual UNION ALL
    SELECT 'ALL_MINILM_L12_V2', 'default_top_k', '10', 'NUMBER', 'Default number of results for similarity search' FROM dual UNION ALL
    SELECT 'ALL_MINILM_L12_V2', 'similarity_threshold', '0.7', 'NUMBER', 'Default similarity threshold' FROM dual
) s
ON (c.model_name = s.model_name AND c.config_key = s.config_key)
WHEN NOT MATCHED THEN
    INSERT (model_name, config_key, config_value, config_type, description)
    VALUES (s.model_name, s.config_key, s.config_value, s.config_type, s.description);

COMMIT;

-- ============================================================================
-- 7. MAINTENANCE PROCEDURES
-- ============================================================================


CREATE OR REPLACE PROCEDURE ai_aggregate_daily_metrics(
    p_target_date   IN DATE DEFAULT TRUNC(SYSDATE - 1)
) AS  ---- Procedure to aggregate daily metrics
    v_count NUMBER;
BEGIN
    -- Check if metrics already exist for this date
    SELECT COUNT(*) INTO v_count
    FROM ai_performance_metrics
    WHERE metric_date = p_target_date;
    
    IF v_count > 0 THEN
        DELETE FROM ai_performance_metrics WHERE metric_date = p_target_date;
    END IF;
    
    -- Aggregate metrics from usage log
    INSERT INTO ai_performance_metrics (
        model_name, metric_date, total_calls, successful_calls, failed_calls,
        avg_latency_ms, min_latency_ms, max_latency_ms, 
        p95_latency_ms, p99_latency_ms, total_tokens, total_execution_ms,
        unique_schemas, unique_users
    )
    SELECT 
        model_name,
        TRUNC(log_timestamp) AS metric_date,
        COUNT(*) AS total_calls,
        SUM(CASE WHEN success_flag = 'Y' THEN 1 ELSE 0 END) AS successful_calls,
        SUM(CASE WHEN success_flag = 'N' THEN 1 ELSE 0 END) AS failed_calls,
        ROUND(AVG(execution_time_ms), 2) AS avg_latency_ms,
        ROUND(MIN(execution_time_ms), 2) AS min_latency_ms,
        ROUND(MAX(execution_time_ms), 2) AS max_latency_ms,
        ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time_ms), 2) AS p95_latency_ms,
        ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY execution_time_ms), 2) AS p99_latency_ms,
        SUM(tokens_processed) AS total_tokens,
        SUM(execution_time_ms) AS total_execution_ms,
        COUNT(DISTINCT calling_schema) AS unique_schemas,
        COUNT(DISTINCT calling_user) AS unique_users
    FROM ai_usage_log
    WHERE TRUNC(log_timestamp) = p_target_date
    GROUP BY model_name, TRUNC(log_timestamp);
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Aggregated metrics for ' || TO_CHAR(p_target_date, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('Rows inserted: ' || SQL%ROWCOUNT);
END ai_aggregate_daily_metrics;
/

-- Procedure to cleanup old logs
CREATE OR REPLACE PROCEDURE ai_cleanup_old_logs(
    p_retention_days IN NUMBER DEFAULT 90
) AS
    v_deleted NUMBER;
BEGIN
    DELETE FROM ai_usage_log
    WHERE log_timestamp < SYSTIMESTAMP - (p_retention_days * INTERVAL '1' DAY);

    v_deleted := SQL%ROWCOUNT;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Deleted ' || v_deleted || ' old log records');
END ai_cleanup_old_logs;
/
