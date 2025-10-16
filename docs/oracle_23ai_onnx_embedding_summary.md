# 🧠 Embedding Generation Inside Oracle Database 23ai  
### Based on Oracle Blog: [Use our prebuilt ONNX model now available for embedding generation in Oracle Database 23ai](https://blogs.oracle.com/machinelearning/post/use-our-prebuilt-onnx-model-now-available-for-embedding-generation-in-oracle-database-23ai)

---

## 🔍 Overview
Oracle Database 23ai introduces **native embedding generation** inside the database using a **prebuilt ONNX model**.  
This allows developers and data scientists to **generate vector embeddings directly via SQL or PL/SQL**—no external API calls, no extra infrastructure.

---

## ⚙️ Key Highlights

### 🧩 1. Prebuilt ONNX Embedding Model
Oracle provides a **ready-to-use multilingual ONNX model** (e.g., `multilingual-e5-small.onnx`) that can be loaded directly into the database.

```sql
BEGIN
  DBMS_VECTOR.LOAD_ONNX_MODEL(
      model_name => 'E5_MULTILINGUAL',
      model_data => BFILENAME('ONNX_DIR', 'multilingual-e5-small.onnx')
  );
END;
/
```

Once loaded, generate embeddings with:

```sql
SELECT VECTOR_EMBEDDING(E5_MULTILINGUAL USING 'Oracle 23ai supports vector search' AS data) AS embedding
FROM dual;
```

---

### 🧠 2. Embedded Vector Generation
- The model executes **inside Oracle Database** (no data movement).
- Enables low-latency, secure embedding generation.
- Perfect for **semantic search**, **document similarity**, **RAG pipelines**, and **recommendation systems**.

---

### 🏗️ 3. Unified Vector Database Architecture
Oracle 23ai includes full **vector database capabilities**—you can store, index, and query embeddings natively.

```sql
CREATE TABLE ai_documents (
  doc_id NUMBER PRIMARY KEY,
  content CLOB,
  doc_vector VECTOR(384)
);

SELECT doc_id,
       1 - VECTOR_DISTANCE(doc_vector, :query_vec, COSINE) AS similarity
FROM ai_documents
ORDER BY similarity DESC
FETCH FIRST 10 ROWS ONLY;
```

---

### 🔄 4. End-to-End AI Workflow
Oracle 23ai unifies all AI lifecycle steps:
1. **Store Data**
2. **Generate Embeddings**
3. **Perform Semantic Search**
4. **Integrate Results into LLM Applications (RAG, Chatbots, etc.)**

This means no separate vector DBs, no middle layers — **just SQL + PL/SQL inside Oracle**.

---

### 💼 5. Business Impact
| Benefit | Description |
|----------|--------------|
| ⚡ Reduced Latency | Embeddings generated directly in the DB |
| 🔒 Improved Security | Data never leaves Oracle Database |
| 🧩 Simplified Architecture | Eliminate external model hosting |
| 💰 Lower Cost | Unified platform for data + AI workloads |

---

## 🧩 Example Workflow: Semantic Search

```sql
-- 1. Create table for vector storage
CREATE TABLE ai_docs (
  doc_id NUMBER PRIMARY KEY,
  content CLOB,
  embedding VECTOR(384)
);

-- 2. Generate and insert embedding
INSERT INTO ai_docs (doc_id, content, embedding)
VALUES (
  1,
  'Oracle Database 23ai introduces built-in vector support.',
  VECTOR_EMBEDDING(E5_MULTILINGUAL USING 'Oracle Database 23ai introduces built-in vector support.' AS data)
);
```

---

## 🧰 Setup Instructions

### Step 1: Create Directory for ONNX Models
```sql
CREATE OR REPLACE DIRECTORY ONNX_DIR AS 
'/u03/dbfs/3E9D9956815F9BD6E063BB5D000A1D1F/data/DATA_PUMP_DIR';
GRANT READ, WRITE ON DIRECTORY ONNX_DIR TO AI;
```

### Step 2: Load the Prebuilt Model
```sql
BEGIN
  DBMS_VECTOR.LOAD_ONNX_MODEL(
      model_name => 'E5_MULTILINGUAL',
      model_data => BFILENAME('ONNX_DIR', 'multilingual-e5-small.onnx')
  );
END;
/
```

### Step 3: Verify Model is Loaded
```sql
SELECT model_name, algorithm, mining_function, creation_date
FROM user_mining_models
WHERE model_name = 'E5_MULTILINGUAL';
```

---

## 📊 Use Cases
- **Semantic search** in enterprise documents  
- **Contextual similarity** for chatbots and assistants  
- **Vector-based recommendations**  
- **Retrieval-Augmented Generation (RAG)** applications fully inside Oracle 23ai  

---

## 🧾 Reference
📖 Original Oracle Blog:  
[Use our prebuilt ONNX model now available for embedding generation in Oracle Database 23ai](https://blogs.oracle.com/machinelearning/post/use-our-prebuilt-onnx-model-now-available-for-embedding-generation-in-oracle-database-23ai)

---

## 🧑‍💻 Author
**Alaaeldin Abdelmonem**  
AI Product & Solutions Architect  
[LinkedIn](https://www.linkedin.com/in/alaa-eldin/) • [GitHub](https://github.com/alaaeldin-abdelmonem)
