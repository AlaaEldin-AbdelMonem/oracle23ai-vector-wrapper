- ============================================
-- GRANT REQUIRED PRIVILEGES FOR VECTOR/ONNX
-- Execute as ADMIN user
-- ============================================
--<<"AI">> is a custom db user that I use as the shared schema for embedding Models, you can replace by any of yours

  -- 1. Grant DB_DEVELOPER_ROLE (includes CREATE MINING MODEL privilege)
GRANT DB_DEVELOPER_ROLE TO AI;

-- 2. Grant specific Data Mining privileges
GRANT CREATE MINING MODEL TO AI;
 

-- 3. Grant Vector-related privileges
GRANT EXECUTE ON DBMS_VECTOR TO AI;
 

-- 4. Grant ONNX directory access
GRANT READ, WRITE ON DIRECTORY ONNX_DIR TO AI;

-- 5. Grant DBMS_CLOUD for Object Storage access
GRANT EXECUTE ON DBMS_CLOUD TO AI;

-- 6. Verify grants
SELECT privilege 
FROM dba_sys_privs 
WHERE grantee = 'AI'
ORDER BY privilege;
