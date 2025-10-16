create or replace PACKAGE ai_vector_util AS
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

    C_MODEL_NAME            CONSTANT VARCHAR2(100) := 'ALL_MINILM_L12_V2';--default model installed,used if not specify a model
    C_VECTOR_DIMENSIONS     CONSTANT NUMBER := 384;
    C_MAX_TEXT_LENGTH       CONSTANT NUMBER := 8000; -- tokens
    C_DEFAULT_TOP_K         CONSTANT NUMBER := 10;
    C_DEFAULT_SIMILARITY    CONSTANT NUMBER := 0.7;
    C_BATCH_SIZE_LIMIT      CONSTANT NUMBER := 100;

    -- ========================================================================
    -- TYPES
    -- ========================================================================

    TYPE t_text_array IS TABLE OF CLOB INDEX BY PLS_INTEGER;
    TYPE t_vector_array IS TABLE OF VECTOR INDEX BY PLS_INTEGER;

    TYPE t_similarity_result IS RECORD (
        row_id          VARCHAR2(100),
        similarity      NUMBER,
        text_content    CLOB,
        metadata        JSON
    );

    TYPE t_similarity_results IS TABLE OF t_similarity_result;

    TYPE t_model_info IS RECORD (
        model_name          VARCHAR2(100),
        model_type          VARCHAR2(50),
        vector_dimensions   NUMBER,
        is_active           CHAR(1),
        last_used           TIMESTAMP,
        usage_count         NUMBER,
        avg_latency_ms      NUMBER
    );

    -- ========================================================================
    -- EXCEPTIONS
    -- ========================================================================

    EX_MODEL_NOT_FOUND      EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_MODEL_NOT_FOUND, -20001);

    EX_TEXT_TOO_LONG        EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_TEXT_TOO_LONG, -20002);

    EX_INVALID_VECTOR       EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_INVALID_VECTOR, -20003);

    EX_EMBEDDING_FAILED     EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_EMBEDDING_FAILED, -20004);

    EX_RATE_LIMIT_EXCEEDED  EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_RATE_LIMIT_EXCEEDED, -20005);

    EX_BATCH_SIZE_EXCEEDED  EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_BATCH_SIZE_EXCEEDED, -20006);

    -- ========================================================================
    -- CORE EMBEDDING FUNCTIONS
    -- ========================================================================

    /**
     * Generate embedding vector for a single text input
     * 
     * @param p_text - Input text to embed (CLOB)
     * @param p_model_name - Model to use (default: ALL_MINILM_L12_V2)
     * @param p_normalize - Normalize vector (default: TRUE)
     * @param p_log_usage - Log this operation (default: TRUE)
     * @return VECTOR(384) - Embedding vector
     * @throws EX_TEXT_TOO_LONG if text exceeds limits
     * @throws EX_EMBEDDING_FAILED if generation fails
     */
    FUNCTION generate_embedding(
        p_text          IN CLOB,
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME,
        p_normalize     IN BOOLEAN DEFAULT TRUE,
        p_log_usage     IN BOOLEAN DEFAULT TRUE
    ) RETURN VECTOR;

    /**
     * Generate embeddings for multiple texts in batch
     * More efficient than multiple single calls
     * 
     * @param p_text_array - Array of texts to embed
     * @param p_model_name - Model to use
     * @param p_normalize - Normalize vectors
     * @return t_vector_array - Array of embedding vectors
     * @throws EX_BATCH_SIZE_EXCEEDED if batch too large
     */
    FUNCTION generate_embedding_batch(
        p_text_array    IN t_text_array,
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME,
        p_normalize     IN BOOLEAN DEFAULT TRUE
    ) RETURN t_vector_array;

    -- ========================================================================
    -- SIMILARITY & SEARCH FUNCTIONS
    -- ========================================================================

    /**
     * Calculate cosine similarity between two vectors
     * Returns value between -1 and 1 (1 = identical, 0 = orthogonal, -1 = opposite)
     * 
     * @param p_vector1 - First vector
     * @param p_vector2 - Second vector
     * @return NUMBER - Similarity score
     */
    FUNCTION cosine_similarity(
        p_vector1       IN VECTOR,
        p_vector2       IN VECTOR
    ) RETURN NUMBER;

    /**
     * Find most similar vectors in a table using vector index
     * 
     * @param p_query_vector - Query vector to search for
     * @param p_schema_name - Schema containing table
     * @param p_table_name - Table name
     * @param p_vector_column - Column containing vectors
     * @param p_id_column - Primary key column (default: ID)
     * @param p_text_column - Text content column (optional)
     * @param p_top_k - Number of results (default: 10)
     * @param p_threshold - Minimum similarity (default: 0.7)
     * @return SYS_REFCURSOR - Result set with similarities
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
    ) RETURN SYS_REFCURSOR;

    /**
     * Semantic search: text to similar texts
     * Combines embedding + similarity search
     * 
     * @param p_query_text - Search query text
     * @param p_schema_name - Schema containing documents
     * @param p_table_name - Table name
     * @param p_vector_column - Column containing vectors
     * @param p_text_column - Text content column
     * @param p_top_k - Number of results
     * @param p_threshold - Minimum similarity
     * @return t_similarity_results - Pipelined results
     */
    FUNCTION semantic_search(
        p_query_text        IN CLOB,
        p_schema_name       IN VARCHAR2,
        p_table_name        IN VARCHAR2,
        p_vector_column     IN VARCHAR2,
        p_text_column       IN VARCHAR2,
        p_top_k             IN NUMBER DEFAULT C_DEFAULT_TOP_K,
        p_threshold         IN NUMBER DEFAULT C_DEFAULT_SIMILARITY
    ) RETURN t_similarity_results PIPELINED;

    -- ========================================================================
    -- UTILITY FUNCTIONS
    -- ========================================================================

    /**
     * Validate text length is within model limits
     * 
     * @param p_text - Text to validate
     * @param p_model_name - Model to check against
     * @return BOOLEAN - TRUE if valid
     */
    FUNCTION validate_text_length(
        p_text          IN CLOB,
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME
    ) RETURN BOOLEAN;

    /**
     * Estimate token count for text
     * Approximate: words * 1.3 (English)
     * 
     * @param p_text - Text to analyze
     * @return NUMBER - Estimated tokens
     */
    FUNCTION estimate_tokens(
        p_text          IN CLOB
    ) RETURN NUMBER;

    /**
     * Chunk text into smaller pieces for embedding
     * Useful for long documents
     * 
     * @param p_text - Text to chunk
     * @param p_chunk_size - Target size in tokens (default: 512)
     * @param p_overlap - Overlap between chunks (default: 50)
     * @return t_text_array - Array of text chunks
     */
    FUNCTION chunk_text(
        p_text          IN CLOB,
        p_chunk_size    IN NUMBER DEFAULT 512,
        p_overlap       IN NUMBER DEFAULT 50
    ) RETURN t_text_array;

    /**
     * Normalize vector to unit length
     * 
     * @param p_vector - Vector to normalize
     * @return VECTOR - Normalized vector
     */
    FUNCTION normalize_vector(
        p_vector        IN VECTOR
    ) RETURN VECTOR;

    -- ========================================================================
    -- MODEL MANAGEMENT FUNCTIONS
    -- ========================================================================

    /**
     * Get information about a model
     * 
     * @param p_model_name - Model name (default: active model)
     * @return t_model_info - Model details
     */
    FUNCTION get_model_info(
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME
    ) RETURN t_model_info;

    /**
     * Check if model is available and healthy
     * 
     * @param p_model_name - Model name
     * @return VARCHAR2 - 'HEALTHY', 'DEGRADED', 'DOWN'
     */
    FUNCTION health_check(
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME
    ) RETURN VARCHAR2;

    /**
     * Get list of available models
     * 
     * @return SYS_REFCURSOR - List of models
     */
    FUNCTION list_models
    RETURN SYS_REFCURSOR;

    -- ========================================================================
    -- LOGGING & MONITORING FUNCTIONS
    -- ========================================================================

    /**
     * Log API usage for tracking and billing
     * Internal use - called automatically by other functions
     * 
     * @param p_operation - Operation type
     * @param p_model_name - Model used
     * @param p_input_length - Input text length
     * @param p_execution_time - Time taken in ms
     * @param p_success - Success flag
     * @param p_error_msg - Error message if failed
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
    );

    /**
     * Get usage statistics for calling schema
     * 
     * @param p_days_back - Number of days to look back (default: 7)
     * @return SYS_REFCURSOR - Usage stats
     */
    FUNCTION get_usage_stats(
        p_days_back     IN NUMBER DEFAULT 7
    ) RETURN SYS_REFCURSOR;

    /**
     * Get performance metrics
     * 
     * @param p_model_name - Model name
     * @param p_days_back - Days to analyze
     * @return SYS_REFCURSOR - Performance data
     */
    FUNCTION get_performance_metrics(
        p_model_name    IN VARCHAR2 DEFAULT C_MODEL_NAME,
        p_days_back     IN NUMBER DEFAULT 7
    ) RETURN SYS_REFCURSOR;

    -- ========================================================================
    -- CONVENIENCE PROCEDURES
    -- ========================================================================

    /**
     * One-shot embedding and insert
     * Generate embedding and insert into table
     * 
     * @param p_text - Text to embed
     * @param p_schema_name - Target schema
     * @param p_table_name - Target table
     * @param p_id_column - ID column name
     * @param p_id_value - ID value
     * @param p_text_column - Text column name
     * @param p_vector_column - Vector column name
     */
    PROCEDURE embed_and_insert(
        p_text              IN CLOB,
        p_schema_name       IN VARCHAR2,
        p_table_name        IN VARCHAR2,
        p_id_column         IN VARCHAR2,
        p_id_value          IN VARCHAR2,
        p_text_column       IN VARCHAR2,
        p_vector_column     IN VARCHAR2
    );

    /**
     * Batch embed and bulk insert
     * 
     * @param p_text_array - Array of texts
     * @param p_schema_name - Target schema
     * @param p_table_name - Target table
     * @param p_vector_column - Vector column name
     */
    PROCEDURE batch_embed_and_insert(
        p_text_array        IN t_text_array,
        p_schema_name       IN VARCHAR2,
        p_table_name        IN VARCHAR2,
        p_vector_column     IN VARCHAR2
    );

END ai_vector_util;
/
