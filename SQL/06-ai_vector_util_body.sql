create or replace PACKAGE BODY ai_vector_util AS
-- ============================================================================
-- Centralized AI Vector Utility Package Body
-- ============================================================================
-- Schema      : AI
-- Version     : 1.0
-- Author      : Alaaeldin Abdelmonem
-- LinkedIn    : https://www.linkedin.com/in/alaa-eldin/
-- GitHub      : https://github.com/alaaeldin-abdelmonem
-- Date        : October 15, 2025
-- ============================================================================
-- Description :
--   Provides centralized utilities and helper functions for AI Vector
--   operations, including embedding generation, normalization, similarity
--   search, and AI model usage tracking.
--
--   This package acts as the backbone for Oracle 23ai-based AI features
--   and RAG (Retrieval-Augmented Generation) pipelines. It encapsulates:
--     • Embedding generation (single and batch)
--     • Similarity & semantic search utilities
--     • Logging and monitoring of AI model usage
--     • Health checks and vector normalization routines
--     • Cleanup and performance metrics retrieval
--
--   Designed for enterprise AI applications integrated with Oracle APEX,
--   leveraging Oracle’s built-in Vector Datatype, ONNEX models, and
--   Autonomous Database AI features.
--
-- Change Log :
--   v1.0  (Oct 15, 2025)  - Initial release of AI Vector Utility package.
-- ============================================================================
    /**
     * Get calling schema name
     */
    FUNCTION get_calling_schema RETURN VARCHAR2 IS
        v_schema VARCHAR2(128);
    BEGIN
        SELECT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
        INTO v_schema
        FROM dual;
        RETURN v_schema;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN USER;
    END get_calling_schema;

    /**
     * Get calling user
     */
    FUNCTION get_calling_user RETURN VARCHAR2 IS
    BEGIN
        RETURN SYS_CONTEXT('USERENV', 'SESSION_USER');
    END get_calling_user;

    /**
     * Get session ID
     */
    FUNCTION get_session_id RETURN VARCHAR2 IS
    BEGIN
        RETURN SYS_CONTEXT('USERENV', 'SESSIONID');
    END get_session_id;

    /**
     * Validate model exists
     */
    FUNCTION model_exists(p_model_name IN VARCHAR2) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM user_mining_models
        WHERE model_name = UPPER(p_model_name);

        RETURN v_count > 0;
    END model_exists;

    -- ========================================================================
    -- PUBLIC FUNCTION IMPLEMENTATIONS
    -- ========================================================================

    /**
     * Generate embedding for single text
     */
    FUNCTION generate_embedding(
        p_text          IN CLOB,
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME,
        p_normalize     IN BOOLEAN DEFAULT TRUE,
        p_log_usage     IN BOOLEAN DEFAULT TRUE
    ) RETURN VECTOR IS
        v_embedding         VECTOR;
        v_start_time        TIMESTAMP;
        v_end_time          TIMESTAMP;
        v_execution_ms      NUMBER;
        v_text_length       NUMBER;
        v_tokens            NUMBER;
        v_model_name        VARCHAR2(100) := UPPER(p_model_name);
    BEGIN
        v_start_time := SYSTIMESTAMP;

        -- Validate model exists
        IF NOT model_exists(v_model_name) THEN
            RAISE_APPLICATION_ERROR(-20001, 
                'Model not found: ' || v_model_name);
        END IF;

        -- Validate text length
        v_text_length := DBMS_LOB.GETLENGTH(p_text);
        IF v_text_length = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 
                'Input text cannot be empty');
        END IF;

        v_tokens := estimate_tokens(p_text);
        IF v_tokens > C_MAX_TEXT_LENGTH THEN
            RAISE_APPLICATION_ERROR(-20002, 
                'Text too long: ' || v_tokens || ' tokens (max: ' || 
                C_MAX_TEXT_LENGTH || ')');
        END IF;

        -- Generate embedding using dynamic SQL to handle model name
        EXECUTE IMMEDIATE 
            'SELECT VECTOR_EMBEDDING(' || v_model_name || 
            ' USING :text AS data) FROM dual'
        INTO v_embedding
        USING p_text;

        -- Normalize if requested
        IF p_normalize THEN
            v_embedding := normalize_vector(v_embedding);
        END IF;

        -- Calculate execution time
        v_end_time := SYSTIMESTAMP;
        v_execution_ms := EXTRACT(SECOND FROM (v_end_time - v_start_time)) * 1000;

        -- Log usage
        IF p_log_usage THEN
            log_usage(
                p_operation => 'EMBED_SINGLE',
                p_model_name => v_model_name,
                p_input_length => v_text_length,
                p_execution_time => v_execution_ms,
                p_tokens_processed => v_tokens,
                p_success => 'Y'
            );
        END IF;

        RETURN v_embedding;

    EXCEPTION
        WHEN OTHERS THEN
            -- Log failure
            IF p_log_usage THEN
                log_usage(
                    p_operation => 'EMBED_SINGLE',
                    p_model_name => v_model_name,
                    p_input_length => v_text_length,
                    p_success => 'N',
                    p_error_msg => SQLERRM
                );
            END IF;

            RAISE_APPLICATION_ERROR(-20004, 
                'Embedding generation failed: ' || SQLERRM);
    END generate_embedding;

    /**
     * Generate embeddings for batch
     */
    FUNCTION generate_embedding_batch(
        p_text_array    IN t_text_array,
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME,
        p_normalize     IN BOOLEAN DEFAULT TRUE
    ) RETURN t_vector_array IS
        v_embeddings        t_vector_array;
        v_start_time        TIMESTAMP;
        v_end_time          TIMESTAMP;
        v_execution_ms      NUMBER;
        v_total_length      NUMBER := 0;
        v_total_tokens      NUMBER := 0;
        v_batch_size        NUMBER;
    BEGIN
        v_start_time := SYSTIMESTAMP;
        v_batch_size := p_text_array.COUNT;

        -- Validate batch size
        IF v_batch_size > C_BATCH_SIZE_LIMIT THEN
            RAISE_APPLICATION_ERROR(-20006, 
                'Batch size ' || v_batch_size || ' exceeds limit ' || C_BATCH_SIZE_LIMIT);
        END IF;

        -- Process each text
        FOR i IN 1..v_batch_size LOOP
            v_embeddings(i) := generate_embedding(
                p_text => p_text_array(i),
                p_model_name => p_model_name,
                p_normalize => p_normalize,
                p_log_usage => FALSE  -- We'll log batch operation separately
            );

            v_total_length := v_total_length + DBMS_LOB.GETLENGTH(p_text_array(i));
            v_total_tokens := v_total_tokens + estimate_tokens(p_text_array(i));
        END LOOP;

        -- Calculate execution time
        v_end_time := SYSTIMESTAMP;
        v_execution_ms := EXTRACT(SECOND FROM (v_end_time - v_start_time)) * 1000;

        -- Log batch operation
        log_usage(
            p_operation => 'EMBED_BATCH',
            p_model_name => UPPER(p_model_name),
            p_input_length => v_total_length,
            p_batch_size => v_batch_size,
            p_execution_time => v_execution_ms,
            p_tokens_processed => v_total_tokens,
            p_success => 'Y'
        );

        RETURN v_embeddings;

    EXCEPTION
        WHEN OTHERS THEN
            log_usage(
                p_operation => 'EMBED_BATCH',
                p_model_name => UPPER(p_model_name),
                p_batch_size => v_batch_size,
                p_success => 'N',
                p_error_msg => SQLERRM
            );
            RAISE;
    END generate_embedding_batch;

    /**
     * Calculate cosine similarity
     */
    FUNCTION cosine_similarity(
        p_vector1       IN VECTOR,
        p_vector2       IN VECTOR
    ) RETURN NUMBER IS
        v_similarity NUMBER;
    BEGIN
        -- Use Oracle's built-in vector distance function
        -- COSINE distance, then convert to similarity (1 - distance)
        SELECT 1 - VECTOR_DISTANCE(p_vector1, p_vector2, COSINE)
        INTO v_similarity
        FROM dual;

        RETURN v_similarity;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20003, 
                'Invalid vectors for similarity calculation: ' || SQLERRM);
    END cosine_similarity;

    /**
     * Similarity search in table
     */
    FUNCTION similarity_search(
        p_query_vector      IN VECTOR,
        p_schema_name       IN VARCHAR2,
        p_table_name        IN VARCHAR2,
        p_vector_column     IN VARCHAR2,
        p_id_column         IN VARCHAR2 DEFAULT 'ID',
        p_text_column       IN VARCHAR2 DEFAULT NULL,
        p_top_k             IN NUMBER DEFAULT C_DEFAULT_TOP_K,
        p_threshold         IN NUMBER DEFAULT C_DEFAULT_SIMILARITY
    ) RETURN SYS_REFCURSOR IS
        v_cursor            SYS_REFCURSOR;
        v_sql               VARCHAR2(4000);
        v_full_table        VARCHAR2(200);
    BEGIN
        -- Build fully qualified table name
        v_full_table := p_schema_name || '.' || p_table_name;

        -- Build dynamic SQL
        v_sql := 'SELECT ' || p_id_column || ' AS id, ';
        v_sql := v_sql || '1 - VECTOR_DISTANCE(' || p_vector_column || ', :query_vec, COSINE) AS similarity';

        IF p_text_column IS NOT NULL THEN
            v_sql := v_sql || ', ' || p_text_column || ' AS text_content';
        END IF;

        v_sql := v_sql || ' FROM ' || v_full_table;
        v_sql := v_sql || ' WHERE 1 - VECTOR_DISTANCE(' || p_vector_column || ', :query_vec, COSINE) >= :threshold';
        v_sql := v_sql || ' ORDER BY similarity DESC';
        v_sql := v_sql || ' FETCH FIRST :top_k ROWS ONLY';

        -- Execute and return cursor
        OPEN v_cursor FOR v_sql 
        USING p_query_vector, p_query_vector, p_threshold, p_top_k;

        RETURN v_cursor;

    EXCEPTION
        WHEN OTHERS THEN
            IF v_cursor%ISOPEN THEN
                CLOSE v_cursor;
            END IF;
            RAISE_APPLICATION_ERROR(-20004, 
                'Similarity search failed: ' || SQLERRM);
    END similarity_search;

    /**
     * Semantic search (text to similar texts)
     */
    FUNCTION semantic_search(
        p_query_text        IN CLOB,
        p_schema_name       IN VARCHAR2,
        p_table_name        IN VARCHAR2,
        p_vector_column     IN VARCHAR2,
        p_text_column       IN VARCHAR2,
        p_top_k             IN NUMBER DEFAULT C_DEFAULT_TOP_K,
        p_threshold         IN NUMBER DEFAULT C_DEFAULT_SIMILARITY
    ) RETURN t_similarity_results PIPELINED IS
        v_query_vector      VECTOR;
        v_cursor            SYS_REFCURSOR;
        v_id                VARCHAR2(100);
        v_similarity        NUMBER;
        v_text              CLOB;
        v_result            t_similarity_result;
    BEGIN
        -- Generate embedding for query
        v_query_vector := generate_embedding(p_query_text);

        -- Perform similarity search
        v_cursor := similarity_search(
            p_query_vector => v_query_vector,
            p_schema_name => p_schema_name,
            p_table_name => p_table_name,
            p_vector_column => p_vector_column,
            p_text_column => p_text_column,
            p_top_k => p_top_k,
            p_threshold => p_threshold
        );

        -- Pipe results
        LOOP
            FETCH v_cursor INTO v_id, v_similarity, v_text;
            EXIT WHEN v_cursor%NOTFOUND;

            v_result.row_id := v_id;
            v_result.similarity := v_similarity;
            v_result.text_content := v_text;

            PIPE ROW(v_result);
        END LOOP;

        CLOSE v_cursor;
        RETURN;

    EXCEPTION
        WHEN OTHERS THEN
            IF v_cursor%ISOPEN THEN
                CLOSE v_cursor;
            END IF;
            RAISE;
    END semantic_search;

    /**
     * Validate text length
     */
    FUNCTION validate_text_length(
        p_text          IN CLOB,
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME
    ) RETURN BOOLEAN IS
        v_tokens NUMBER;
    BEGIN
        v_tokens := estimate_tokens(p_text);
        RETURN v_tokens <= C_MAX_TEXT_LENGTH;
    END validate_text_length;

    /**
     * Estimate tokens (rough approximation)
     */
    FUNCTION estimate_tokens(
        p_text          IN CLOB
    ) RETURN NUMBER IS
        v_text_length   NUMBER;
        v_word_count    NUMBER;
        v_tokens        NUMBER;
    BEGIN
        v_text_length := DBMS_LOB.GETLENGTH(p_text);

        IF v_text_length = 0 THEN
            RETURN 0;
        END IF;

        -- Rough estimate: average word length ~5 chars + 1 space
        v_word_count := v_text_length / 6;

        -- Tokens ~= words * 1.3 for English
        v_tokens := ROUND(v_word_count * 1.3);

        RETURN v_tokens;
    END estimate_tokens;

    /**
     * Chunk text into pieces
     */
    FUNCTION chunk_text(
        p_text          IN CLOB,
        p_chunk_size    IN NUMBER DEFAULT 512,
        p_overlap       IN NUMBER DEFAULT 50
    ) RETURN t_text_array IS
        v_chunks        t_text_array;
        v_text_length   NUMBER;
        v_start_pos     NUMBER := 1;
        v_chunk_chars   NUMBER;
        v_overlap_chars NUMBER;
        v_chunk_idx     NUMBER := 1;
        v_chunk_text    CLOB;
    BEGIN
        v_text_length := DBMS_LOB.GETLENGTH(p_text);

        -- Approximate: tokens * 4 = characters (rough)
        v_chunk_chars := p_chunk_size * 4;
        v_overlap_chars := p_overlap * 4;

        WHILE v_start_pos <= v_text_length LOOP
            -- Extract chunk
            v_chunk_text := DBMS_LOB.SUBSTR(p_text, v_chunk_chars, v_start_pos);

            v_chunks(v_chunk_idx) := v_chunk_text;
            v_chunk_idx := v_chunk_idx + 1;

            -- Move to next position with overlap
            v_start_pos := v_start_pos + v_chunk_chars - v_overlap_chars;
        END LOOP;

        RETURN v_chunks;
    END chunk_text;


 /**
 * Normalize vector to unit length
 */
FUNCTION normalize_vector(
    p_vector        IN VECTOR
) RETURN VECTOR IS
    v_normalized VECTOR;
    v_norm NUMBER;
BEGIN
    -- Get vector magnitude
    SELECT VECTOR_NORM(p_vector)
    INTO v_norm
    FROM dual;

    -- If norm is zero, return original
    IF v_norm = 0 THEN
        RETURN p_vector;
    END IF;

    -- Normalize by dividing each component by the norm
    -- Oracle 23ai handles this with VECTOR_SERIALIZE
    SELECT TO_VECTOR(
        '[' || 
        LISTAGG(
            TO_CHAR(
                TO_NUMBER(
                    REGEXP_SUBSTR(FROM_VECTOR(p_vector), '[^,]+', 1, LEVEL)
                ) / v_norm
            ),
            ','
        ) WITHIN GROUP (ORDER BY LEVEL) ||
        ']'
    )
    INTO v_normalized
    FROM dual
    CONNECT BY LEVEL <= VECTOR_DIMENSION_COUNT(p_vector);

    RETURN v_normalized;
EXCEPTION
    WHEN OTHERS THEN
        -- If normalization fails, return original
        RETURN p_vector;
END normalize_vector;

    /**
     * Get model info
     */
    FUNCTION get_model_info(
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME
    ) RETURN t_model_info IS
        v_info          t_model_info;
        v_model_name    VARCHAR2(100) := UPPER(p_model_name);
    BEGIN
        -- Get from user_mining_models
        SELECT 
            model_name,
            mining_function,
            C_VECTOR_DIMENSIONS,
            'Y',
            creation_date,
            0,
            0
        INTO 
            v_info.model_name,
            v_info.model_type,
            v_info.vector_dimensions,
            v_info.is_active,
            v_info.last_used,
            v_info.usage_count,
            v_info.avg_latency_ms
        FROM user_mining_models
        WHERE model_name = v_model_name;

        -- Try to get usage stats from registry if exists
        BEGIN
            SELECT 
                last_used_date,
                usage_count,
                avg_latency_ms
            INTO 
                v_info.last_used,
                v_info.usage_count,
                v_info.avg_latency_ms
            FROM ai_model_registry
            WHERE model_name = v_model_name;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL; -- Keep defaults
        END;

        RETURN v_info;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 
                'Model not found: ' || v_model_name);
    END get_model_info;

    /**
     * Health check
     */
    FUNCTION health_check(
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME
    ) RETURN VARCHAR2 IS
        v_test_vector   VECTOR;
        v_status        VARCHAR2(20);
    BEGIN
        -- Try to generate a test embedding
        BEGIN
            v_test_vector := generate_embedding(
                p_text => 'Health check test',
                p_model_name => p_model_name,
                p_log_usage => FALSE
            );

            IF v_test_vector IS NOT NULL THEN
                v_status := 'HEALTHY';
            ELSE
                v_status := 'DEGRADED';
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                v_status := 'DOWN';
        END;

        RETURN v_status;
    END health_check;

    /**
     * List all models
     */
    FUNCTION list_models
    RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
        SELECT 
            model_name,
            mining_function,
            algorithm,
            creation_date,
            model_size
        FROM user_mining_models
        ORDER BY creation_date DESC;

        RETURN v_cursor;
    END list_models;

    /**
     * Log usage
     */
 /**
 * Log usage
 */
PROCEDURE log_usage(
    p_operation         IN VARCHAR2,
    p_model_name        IN VARCHAR2,
    p_input_length      IN NUMBER DEFAULT NULL,
    p_batch_size        IN NUMBER DEFAULT NULL,
    p_execution_time    IN NUMBER DEFAULT NULL,
    p_tokens_processed  IN NUMBER DEFAULT NULL,
    p_success           IN CHAR DEFAULT 'Y',
    p_error_msg         IN VARCHAR2 DEFAULT NULL
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_session_id    VARCHAR2(100);
    v_schema        VARCHAR2(128);
    v_user          VARCHAR2(128);
BEGIN
    -- Call functions before INSERT to avoid SQL context issues
    v_session_id := get_session_id();
    v_schema := get_calling_schema();
    v_user := get_calling_user();

    INSERT INTO ai_usage_log (
        session_id,
        calling_schema,
        calling_user,
        model_name,
        operation_type,
        input_text_length,
        batch_size,
        execution_time_ms,
        tokens_processed,
        success_flag,
        error_message
    ) VALUES (
        v_session_id,
        v_schema,
        v_user,
        p_model_name,
        p_operation,
        p_input_length,
        p_batch_size,
        p_execution_time,
        p_tokens_processed,
        p_success,
        SUBSTR(p_error_msg, 1, 4000)
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        -- Don't fail the main operation if logging fails
        NULL;
END log_usage;

    /**
     * Get usage stats
     */
   FUNCTION get_usage_stats(
    p_days_back     IN NUMBER DEFAULT 7
) RETURN SYS_REFCURSOR IS
    v_cursor        SYS_REFCURSOR;
    v_schema        VARCHAR2(128);
BEGIN
    v_schema := get_calling_schema();

    OPEN v_cursor FOR
    SELECT 
        TRUNC(log_timestamp) AS usage_date,
        operation_type,
        model_name,
        COUNT(*) AS total_calls,
        SUM(CASE WHEN success_flag = 'Y' THEN 1 ELSE 0 END) AS successful_calls,
        SUM(CASE WHEN success_flag = 'N' THEN 1 ELSE 0 END) AS failed_calls,
        ROUND(AVG(execution_time_ms), 2) AS avg_latency_ms,
        SUM(tokens_processed) AS total_tokens
    FROM ai_usage_log
    WHERE calling_schema = v_schema
      AND log_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(p_days_back, 'DAY')
    GROUP BY TRUNC(log_timestamp), operation_type, model_name
    ORDER BY usage_date DESC, total_calls DESC;

    RETURN v_cursor;
END get_usage_stats;

    /**
     * Get performance metrics
     */
    FUNCTION get_performance_metrics(
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME,
        p_days_back     IN NUMBER DEFAULT 7
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
        SELECT 
            metric_date,
            model_name,
            total_calls,
            successful_calls,
            failed_calls,
            avg_latency_ms,
            min_latency_ms,
            max_latency_ms,
            p95_latency_ms,
            total_tokens
        FROM ai_performance_metrics
        WHERE model_name = UPPER(p_model_name)
          AND metric_date >= TRUNC(SYSDATE) - p_days_back
        ORDER BY metric_date DESC;

        RETURN v_cursor;
    END get_performance_metrics;

    /**
     * Embed and insert
     */
    PROCEDURE embed_and_insert(
        p_text              IN CLOB,
        p_schema_name       IN VARCHAR2,
        p_table_name        IN VARCHAR2,
        p_id_column         IN VARCHAR2,
        p_id_value          IN VARCHAR2,
        p_text_column       IN VARCHAR2,
        p_vector_column     IN VARCHAR2
    ) IS
        v_embedding     VECTOR;
        v_sql           VARCHAR2(4000);
    BEGIN
        -- Generate embedding
        v_embedding := generate_embedding(p_text);

        -- Build INSERT statement
        v_sql := 'INSERT INTO ' || p_schema_name || '.' || p_table_name;
        v_sql := v_sql || ' (' || p_id_column || ', ' || p_text_column || ', ' || p_vector_column || ')';
        v_sql := v_sql || ' VALUES (:id_val, :text_val, :vec_val)';

        -- Execute
        EXECUTE IMMEDIATE v_sql USING p_id_value, p_text, v_embedding;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20004, 
                'Embed and insert failed: ' || SQLERRM);
    END embed_and_insert;

    /**
     * Batch embed and insert
     */
    PROCEDURE batch_embed_and_insert(
        p_text_array        IN t_text_array,
        p_schema_name       IN VARCHAR2,
        p_table_name        IN VARCHAR2,
        p_vector_column     IN VARCHAR2
    ) IS
        v_embeddings    t_vector_array;
    BEGIN
        -- Generate all embeddings
        v_embeddings := generate_embedding_batch(p_text_array);

        -- Bulk insert (implementation depends on table structure)
        -- This is a simplified version
        FOR i IN 1..v_embeddings.COUNT LOOP
            EXECUTE IMMEDIATE 
                'INSERT INTO ' || p_schema_name || '.' || p_table_name ||
                ' (' || p_vector_column || ') VALUES (:vec)'
            USING v_embeddings(i);
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20004, 
                'Batch embed and insert failed: ' || SQLERRM);
    END batch_embed_and_insert;

END ai_vector_util;
/
