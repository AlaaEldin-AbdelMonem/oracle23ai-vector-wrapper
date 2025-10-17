# oracle23ai-vector-wrapper
 contains a complete, production-ready solution for centralizing AI model access across multiple Oracle schemas. Instead of loading ONNX models in each schema, you have one central AI schema that provides embedding and vector services to all consumer schemas.

 
**Version:** 1.0  
**Date:** October 15, 2025  
**Platform:** Oracle Database 23ai + APEX 24.2.9  
**Author:** AlaaEldin Abdelmoneim

---

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Benefits](#benefits)
4. [Prerequisites](#prerequisites)
5. [Installation Guide](#installation-guide)
6. [Usage Examples](#usage-examples)
7. [API Reference](#api-reference)
8. [Monitoring & Maintenance](#monitoring--maintenance)
9. [Troubleshooting](#troubleshooting)
10. [Files Included](#files-included)

---

## 🎯 Executive Summary

This package provides a **centralized AI model management layer** that allows multiple Oracle schemas to access embedding generation and vector operations through a single, unified API. Instead of each schema loading its own ONNX model and managing AI operations independently, all schemas call functions from a central AI schema.

### Key Features

- ✅ **Centralized Model**: Single ONNX model (all-MiniLM-L12-v2, 384 dimensions)
- ✅ **Unified API**: Consistent interface across all consumer schemas
- ✅ **Usage Tracking**: Comprehensive logging and analytics
- ✅ **Performance Monitoring**: Health checks and metrics
- ✅ **Easy Maintenance**: Update once, applies everywhere
- ✅ **Cost Efficient**: No duplicate model storage

---

## 🏗️ Architecture Overview
I created the centeral ai schema and name it "AI", you change to whatever your centeral one is.
```
┌────────────────────────────────────────┐
│        AI Schema (Central Hub)         │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │   ONNX Model: ALL_MINILM_L12_V2  │  │
│  │   (384-dim embeddings)           │  │
│  └──────────────────────────────────┘  │
│               ↓                        │
│  ┌──────────────────────────────────┐  │
│  │   AI_VECTOR_UTIL Package         │  │
│  │   • generate_embedding()         │  │
│  │   • similarity_search()          │  │
│  │   • semantic_search()            │  │
│  │   • health_check()               │  │
│  └──────────────────────────────────┘  │
│               ↓                        │
│  ┌──────────────────────────────────┐  │
│  │   Metadata Tables & Views        │  │
│  │   • ai_model_registry            │  │
│  │   • ai_usage_log                 │  │
│  │   • v_model_health               │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
              ↓ (EXECUTE grants)
┌────────────────────────────────────────┐
│       Consumer Schemas                 │
│   DBuser1   DBuser2                    │
│      ↓      ↓                          │
│   Call AI.AI_VECTOR_UTIL.*()           │
└────────────────────────────────────────┘
```

---

## ✨ Benefits

### 1. **Simplified Management**
- Load model once in AI schema
- All updates happen in one place
- Consistent behavior across all schemas

### 2. **Cost Efficiency**
- No duplicate 133MB model storage per schema
- Shared compute resources
- Centralized token tracking
 
---

## 📋 Prerequisites

### Database Requirements
- Oracle Database 23ai  
 
 

### Privileges Needed (AI Schema)
```sql
-- AI schema must have:
GRANT CREATE TABLE TO AI;
GRANT CREATE PROCEDURE TO AI;
GRANT CREATE VIEW TO AI;
GRANT CREATE SEQUENCE TO AI;
GRANT UNLIMITED TABLESPACE TO AI;

-- For ONNX model loading:
GRANT EXECUTE ON DBMS_DATA_MINING TO AI;
GRANT EXECUTE ON DBMS_VECTOR TO AI;
GRANT EXECUTE ON DBMS_CLOUD TO AI;
GRANT CREATE MINING MODEL TO AI;
GRANT READ, WRITE ON DIRECTORY ONNX_DIR TO AI;
```

### Consumer Schema Requirements
- Must exist before granting access
- No special privileges needed (just EXECUTE on package)
- Optionaly you can create synonym for the package

---

## 🚀 Installation Guide

### All Scripts are in "SQL" forlder (01,02,...........)

 
---

## 💡 Usage Examples

### Basic Embedding Generation

```sql
select ai_vector_utx.generate_embedding( 'PM Copilot is an AI-powered APEX application') embd from dual;
```

### Batch Processing

```sql
DECLARE
    TYPE text_array IS TABLE OF CLOB INDEX BY PLS_INTEGER;
    v_texts text_array;
    v_embeddings ai_vector_utx.t_vector_array;
BEGIN
    v_texts(1) := 'First document';
    v_texts(2) := 'Second document';
    v_texts(3) := 'Third document';
    
    v_embeddings := ai_vector_utx.generate_embedding_batch(
        p_text_array => v_texts
    );
    
    DBMS_OUTPUT.PUT_LINE('Generated ' || v_embeddings.COUNT || ' embeddings');
END;
/
```

### Semantic Search

```sql
DECLARE
    v_query_text CLOB := 'How to write user stories?';
    v_results SYS_REFCURSOR;
    v_id VARCHAR2(100);
    v_similarity NUMBER;
    v_title VARCHAR2(200);
BEGIN
    -- Search for similar documents
    v_results := ai_vector_utx.similarity_search(
        p_query_vector => ai_vector_util.generate_embedding(v_query_text),
        p_schema_name => '<<<<schema name>>',
        p_table_name => 'PM_DOCUMENT_CHUNKS',
        p_vector_column => 'EMBEDDING',
        p_text_column => 'CHUNK_TEXT',
        p_top_k => 10,
        p_threshold => 0.7
    );
    
    -- Process results
    LOOP
        FETCH v_results INTO v_id, v_similarity, v_title;
        EXIT WHEN v_results%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE(v_title || ': ' || ROUND(v_similarity, 3));
    END LOOP;
    
    CLOSE v_results;
END;
/
```

### Health Check

```sql
SELECT ai_vector_utx.health_check() AS status FROM dual;
-- Returns: HEALTHY, DEGRADED, or DOWN
```

### View Usage Statistics

```sql
-- Your schema's usage
SELECT * FROM AI.ai_daily_usage_by_schema_v
WHERE calling_schema = USER
ORDER BY usage_date DESC;

-- Model health
SELECT * FROM AI.ai_model_health_v;

-- Recent errors
SELECT * FROM AI.ai_error_summary_v;
```

---

## 📚 API Reference

### Core Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `generate_embedding(p_text)` | VECTOR(384) | Generate embedding for text |
| `generate_embedding_batch(p_text_array)` | t_vector_array | Batch embedding generation |
| `cosine_similarity(p_vec1, p_vec2)` | NUMBER | Calculate similarity (-1 to 1) |
| `similarity_search(...)` | SYS_REFCURSOR | Find similar vectors in table |
| `semantic_search(...)` | t_similarity_results | Text to similar texts search |

### Utility Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `validate_text_length(p_text)` | BOOLEAN | Check if text fits in model |
| `estimate_tokens(p_text)` | NUMBER | Estimate token count |
| `chunk_text(p_text, p_chunk_size)` | t_text_array | Split text into chunks |
| `normalize_vector(p_vector)` | VECTOR | Normalize to unit length |

### Management Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `get_model_info()` | t_model_info | Model metadata |
| `health_check()` | VARCHAR2 | Service health status |
| `list_models()` | SYS_REFCURSOR | Available models |
| `get_usage_stats(p_days)` | SYS_REFCURSOR | Usage statistics |

---

## 📊 Monitoring & Maintenance

### Health Monitoring

```sql
-- Check model health
SELECT * FROM AI.ai_model_health_v;

-- Real-time usage (last hour)
SELECT * FROM AI.ai_realtime_usage_v;

-- Error summary
SELECT * FROM AI.ai_error_summary_v
WHERE last_occurrence > SYSDATE - 1;
```

### Daily Maintenance

```sql
-- Aggregate daily metrics (run via scheduler)
BEGIN
    AI.ai_aggregate_daily_metrics(p_target_date => SYSDATE - 1);
END;
/

-- Cleanup old logs (keep 90 days)
BEGIN
    AI.ai_cleanup_old_logs(p_retention_days => 90);
END;
/
```

### Performance Tuning

```sql
-- Identify slow operations
SELECT 
    calling_schema,
    operation_type,
    AVG(execution_time_ms) AS avg_ms,
    MAX(execution_time_ms) AS max_ms,
    COUNT(*) AS occurrences
FROM AI.ai_usage_log
WHERE log_timestamp > SYSDATE - 7
  AND success_flag = 'Y'
GROUP BY calling_schema, operation_type
HAVING AVG(execution_time_ms) > 100
ORDER BY avg_ms DESC;
```

---

## 🔧 Troubleshooting

### Problem: "Model not found" error

**Solution:**
```sql
-- Check if model exists in AI schema
SELECT model_name FROM AI.user_mining_models;

-- If missing, reload model
  Re-check Model loading script in sql folder
```

### Problem: "Insufficient privileges" when calling functions

**Solution:**
```sql
-- Verify grants from AI schema
SELECT grantee, privilege 
FROM AI.user_tab_privs 
WHERE table_name = 'AI_VECTOR_UTIL';

-- Re-run grant script if needed
   sql folder
```

### Problem: Performance is slow

**Solution:**
```sql
-- Check vector index exists on your tables
SELECT index_name, table_name 
FROM user_indexes 
WHERE index_type = 'VECTOR';

-- Create if missing
CREATE VECTOR INDEX idx_embedding 
ON your_table(embedding_column)
ORGANIZATION INMEMORY NEIGHBOR GRAPH
DISTANCE COSINE
WITH TARGET ACCURACY 95;
```

### Problem: "Text too long" error

**Solution:**
```sql
-- Chunk the text first
DECLARE
    v_long_text CLOB := /* your long text */;
    v_chunks ai.ai_vector_util.t_text_array;
BEGIN
    v_chunks := ai.ai_vector_util.chunk_text(
        p_text => v_long_text,
        p_chunk_size => 512,
        p_overlap => 50
    );
    
    -- Process each chunk
    FOR i IN 1..v_chunks.COUNT LOOP
        -- Generate embedding for chunk
        NULL;
    END LOOP;
END;
/
```

---

## 📁 Files Included

 check project directories
---

## 🎓 Best Practices

### 1. Always Use Synonyms
Create synonyms in consumer schemas for cleaner code:
```sql
CREATE SYNONYM  ai_vector_utx FOR AI.ai_vector_util;
```

### 2. Batch When Possible
Use batch operations for multiple texts to improve performance.

### 3. Monitor Usage
Check your usage regularly to understand patterns and costs.

### 4. Handle Errors Gracefully
Always wrap API calls in exception handlers:
```sql
BEGIN
    v_embedding := ai.ai_vector_util.generate_embedding(v_text);
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and handle gracefully
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
```

### 5. Chunk Long Documents
Always chunk documents >2000 words before embedding.

 
## 📄 License

MIT
Oracle Corporation © 2025

---

**Document Version:** 1.0  
**Last Updated:** October 15, 2025  
**Maintained By:** AlaaEldin Abdelmoneim
