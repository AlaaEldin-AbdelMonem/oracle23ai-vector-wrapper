# Centralized AI Model Wrapper Package

## Architecture Design Document

**Version:** 1.0  
**Date:** October 15, 2025  
**Platform:** Oracle 23ai + APEX 24.2.9  

---

## 1. Executive Summary

Create a centralized AI model management layer in a dedicated schema (AI) that provides reusable embedding and vector operations to all PM Copilot application schemas.

### Benefits

- **Single Source of Truth:** One model, one codebase
- **Simplified Maintenance:** Update once, apply everywhere
- **Cost Efficiency:** No duplicate model storage
- **Performance:** Centralized caching and optimization
- **Security:** Controlled access via package grants
- **Scalability:** Easy to add new AI capabilities

---

## 2. Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    AI Schema (Central)                  │
│  ┌───────────────────────────────────────────────────┐  │
│  │         ONNX Model: ALL_MINILM_L12_V2             │  │
│  │         (384-dimension embeddings)                │  │
│  └───────────────────────────────────────────────────┘  │
│                          ↓                              │
│  ┌───────────────────────────────────────────────────┐  │
│  │       PKG_AI_VECTOR_UTIL (Wrapper Package)        │  │
│  │  • generate_embedding()                           │  │
│  │  • generate_embedding_batch()                     │  │
│  │  • similarity_search()                            │  │
│  │  • cosine_similarity()                            │  │
│  │  • get_model_info()                               │  │
│  │  • health_check()                                 │  │
│  └───────────────────────────────────────────────────┘  │
│                          ↓                              │
│  ┌───────────────────────────────────────────────────┐  │
│  │         Configuration & Metadata Tables           │  │
│  │  • ai_model_registry                              │  │
│  │  • ai_usage_log                                   │  │
│  │  • ai_performance_metrics                         │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          ↓ (EXECUTE grants)
┌─────────────────────────────────────────────────────────┐
│              Consumer Schemas (Applications)            │
│                                                         │
│  dbUser1    dbUser2    dbUser3                          │
│    ↓       ↓       ↓       ↓                            │
│  Call AI.PKG_AI_VECTOR_UTIL functions                   │
│    • Document chunking & embedding                      │
│    • RAG search queries                                 │
│    • Similarity matching                                │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Component Specifications

### 3.1 Central Schema (AI)

**Purpose:** Host ONNX models and provide AI services

**Contents:**

1. ONNX Model: `ALL_MINILM_L12_V2`
2. Package: `PKG_AI_VECTOR_UTIL`
3. Tables: Configuration and logging
4. Views: Usage statistics and model info

### 3.2 Wrapper Package Functions

#### Core Functions

| Function                   | Purpose                    | Parameters                       | Returns       |
| -------------------------- | -------------------------- | -------------------------------- | ------------- |
| `generate_embedding`       | Single text to vector      | p_text CLOB                      | VECTOR(384)   |
| `generate_embedding_batch` | Multiple texts to vectors  | p_text_array                     | Vector array  |
| `similarity_search`        | Find similar vectors       | p_query_vector, p_table, p_top_k | SYS_REFCURSOR |
| `cosine_similarity`        | Calculate similarity score | p_vec1, p_vec2                   | NUMBER        |
| `get_model_info`           | Model metadata             | p_model_name                     | JSON          |
| `health_check`             | Service status             | -                                | VARCHAR2      |

#### Utility Functions

| Function               | Purpose           | Parameters             | Returns       |
| ---------------------- | ----------------- | ---------------------- | ------------- |
| `validate_text_length` | Check text size   | p_text                 | BOOLEAN       |
| `chunk_text`           | Split into chunks | p_text, p_chunk_size   | Text array    |
| `log_usage`            | Track API calls   | p_schema, p_operation  | -             |
| `get_usage_stats`      | Usage analytics   | p_schema, p_date_range | SYS_REFCURSOR |

---

## 4. Data Model

### 4.1 Model Registry Table

```sql
CREATE TABLE ai_model_registry (
    model_id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_name          VARCHAR2(100) NOT NULL UNIQUE,
    model_type          VARCHAR2(50) NOT NULL, -- ONNX, PRETRAINED, CUSTOM
    mining_function     VARCHAR2(50), -- EMBEDDING, CLASSIFICATION, etc.
    vector_dimensions   NUMBER,
    model_version       VARCHAR2(50),
    model_source        VARCHAR2(500),
    model_file_path     VARCHAR2(500),
    is_active           CHAR(1) DEFAULT 'Y',
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    created_by          VARCHAR2(100),
    last_used_date      TIMESTAMP,
    usage_count         NUMBER DEFAULT 0,
    avg_latency_ms      NUMBER,
    model_metadata      JSON,
    CONSTRAINT chk_active CHECK (is_active IN ('Y', 'N'))
);
```

### 4.2 Usage Logging Table

```sql
CREATE TABLE ai_usage_log (
    log_id              NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id          VARCHAR2(100),
    calling_schema      VARCHAR2(100) NOT NULL,
    calling_user        VARCHAR2(100),
    model_name          VARCHAR2(100) NOT NULL,
    operation_type      VARCHAR2(50) NOT NULL, -- EMBED_SINGLE, EMBED_BATCH, SIMILARITY
    input_text_length   NUMBER,
    batch_size          NUMBER,
    execution_time_ms   NUMBER,
    tokens_processed    NUMBER,
    success_flag        CHAR(1),
    error_message       VARCHAR2(4000),
    log_timestamp       TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT chk_success CHECK (success_flag IN ('Y', 'N'))
);

CREATE INDEX idx_usage_schema_date ON ai_usage_log(calling_schema, log_timestamp);
CREATE INDEX idx_usage_model ON ai_usage_log(model_name, log_timestamp);
```

### 4.3 Performance Metrics Table

```sql
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
    total_tokens        NUMBER,
    CONSTRAINT uk_perf_model_date UNIQUE (model_name, metric_date)
);
```

---

## 5. Security Model

### 5.1 Grant Strategy

```sql
-- Grant EXECUTE on wrapper package to consumer schemas
GRANT EXECUTE ON AI.AI_VECTOR_UTIL TO DBuser1;
GRANT EXECUTE ON AI.AI_VECTOR_UTIL TO DBuser2;
GRANT EXECUTE ON AI.AI_VECTOR_UTIL TO DBuser3;


-- Grant SELECT on registry views (read-only)
GRANT SELECT ON AI.MODEL_REGISTRY_V TO PUBLIC;
GRANT SELECT ON AI.USAGE_STATS_V TO PUBLIC;

-- NO direct access to:
-- • ONNX models
-- • Raw tables
-- • DBMS_VECTOR package
```

### 5.2 Access Control

- **Consumer schemas:** Can only call package functions
- **Cannot:** Direct model access, table modifications
- **Audit:** All calls logged with schema/user info
- **Rate limiting:** Optional (future enhancement)

## 7. Usage Examples

### 7.1 From DB Schema

```sql
-- Generate single embedding
DECLARE
    v_embedding VECTOR(384);
BEGIN
    v_embedding := AI.AI_VECTOR_UTIL.generate_embedding(
        p_text => 'PM Copilot is an AI-powered Oracle APEX application'
    );

    -- Use the embedding
    INSERT INTO my_document_chunks (chunk_text, embedding)
    VALUES ('PM Copilot is...', v_embedding);
END;
```

### 7.2 Batch Processing

```sql
-- Process multiple documents
DECLARE
    TYPE text_array IS TABLE OF CLOB;
    v_texts text_array;
    v_embeddings SYS.ODCIVECTOR;
BEGIN
    v_texts := text_array(
        'First document text...',
        'Second document text...',
        'Third document text...'
    );

    v_embeddings := AI.AI_VECTOR_UTIL.generate_embedding_batch(
        p_text_array => v_texts
    );

    -- Process results
    FOR i IN 1..v_embeddings.COUNT LOOP
        -- Store embeddings
        NULL;
    END LOOP;
END;
```

### 7.3 Similarity Search

```sql
-- Find similar documents
DECLARE
    v_query_vector VECTOR(384);
    v_results SYS_REFCURSOR;
    v_doc_id NUMBER;
    v_similarity NUMBER;
BEGIN
    -- Get query embedding
    v_query_vector := AI.AI_VECTOR_UTIL.generate_embedding(
        p_text => 'user stories for product management'
    );

    -- Search similar documents
    v_results := AI.AI_VECTOR_UTIL.similarity_search(
        p_query_vector => v_query_vector,
        p_table_name => 'AI7P.PM_DOCUMENT_CHUNKS',
        p_vector_column => 'EMBEDDING',
        p_top_k => 10,
        p_threshold => 0.7
    );

    -- Process results
    LOOP
        FETCH v_results INTO v_doc_id, v_similarity;
        EXIT WHEN v_results%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('Doc: ' || v_doc_id || ', Score: ' || v_similarity);
    END LOOP;
END;
```

---

## 8. Monitoring & Observability

### 8.1 Key Metrics

- **Usage:** Calls per schema per day
- **Performance:** P50, P95, P99 latencies
- **Reliability:** Success rate, error patterns
- **Cost:** Token consumption, compute time

### 8.2 Dashboard Views

```sql
-- Daily usage by schema
  VIEW ai_daily_usage_by_schema_v  


-- Model health status
 VIEW ai_model_health_v  
---

## 9. Error Handling Strategy

### 9.1 Exception Types

| Exception             | Code   | Handling           |
|-----------------------|--------|--------------------|
| `MODEL_NOT_FOUND`     | -20001 | Return error, log  |
| `TEXT_TOO_LONG`       | -20002 | Truncate or reject |
| `INVALID_VECTOR`      | -20003 | Validate input     |
| `EMBEDDING_FAILED`    | -20004 | Retry, log error   |
| `RATE_LIMIT_EXCEEDED` | -20005 | Queue or reject    |


##    Maintenance & Support

###   Model Updates
--do not forget to update package specs with default model constant if neccessary
```sql
-- Update model version
BEGIN
    AI.AI_VECTOR_UTIL.update_model(
        p_old_model_name => 'ALL_MINILM_L12_V2',
        p_new_model_name => 'ALL_MINILM_L12_V3',
        p_migration_strategy => 'ROLLING' -- or 'IMMEDIATE'
    );
END;
```

## Cost Management

### .1 Token Tracking

```sql
-- Token consumption by schema
SELECT 
    calling_schema,
    SUM(tokens_processed) AS total_tokens,
    COUNT(*) AS total_calls,
    ROUND(SUM(tokens_processed) / COUNT(*), 2) AS avg_tokens_per_call
FROM ai_usage_log
WHERE log_timestamp > SYSDATE - 30
GROUP BY calling_schema
ORDER BY total_tokens DESC;
```
