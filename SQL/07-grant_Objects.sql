-- ============================================================================
--   AI Model Access Grants
 
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    TYPE t_schema_array IS TABLE OF VARCHAR2(30);
    v_consumer_schemas t_schema_array;
    v_grant_count NUMBER := 0;
    v_error_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE(' AI Access Grant Script');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Define all consumer schemas
    v_consumer_schemas := t_schema_array(
        'SCHMEA1',--your db schema or user that uses the vector model
        'SCHMEA2',
        'SCHMEA3' 
    );
    
    -- Grant EXECUTE on the main package
    DBMS_OUTPUT.PUT_LINE('Granting EXECUTE on AI_VECTOR_UTIL...');
    FOR i IN 1..v_consumer_schemas.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE 
                'GRANT EXECUTE ON ai_vector_util TO ' || v_consumer_schemas(i);
            DBMS_OUTPUT.PUT_LINE('  ✓ Granted to ' || v_consumer_schemas(i));
            v_grant_count := v_grant_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('  ✗ Failed for ' || v_consumer_schemas(i) || ': ' || SQLERRM);
                v_error_count := v_error_count + 1;
        END;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Granting SELECT on monitoring views...');
    
    -- Grant SELECT on views (read-only monitoring)
    FOR i IN 1..v_consumer_schemas.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE 'GRANT SELECT ON ai_model_registry_V TO '        || v_consumer_schemas(i);
            EXECUTE IMMEDIATE 'GRANT SELECT ON ai_daily_usage_by_schema_v TO ' || v_consumer_schemas(i);
            EXECUTE IMMEDIATE 'GRANT SELECT ON ai_realtime_usage_v    TO '     || v_consumer_schemas(i);
            EXECUTE IMMEDIATE 'GRANT SELECT ON ai_error_summary_v     TO '     || v_consumer_schemas(i);
            EXECUTE IMMEDIATE 'GRANT SELECT ON ai_model_health_v      TO '     || v_consumer_schemas(i);
            DBMS_OUTPUT.PUT_LINE('  ✓ View access granted to ' || v_consumer_schemas(i));
            v_grant_count := v_grant_count + 5;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('  ✗ View access failed for ' || v_consumer_schemas(i) || ': ' || SQLERRM);
                v_error_count := v_error_count + 1;
        END;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('Grant Summary:');
    DBMS_OUTPUT.PUT_LINE('  Total grants: ' || v_grant_count);
    DBMS_OUTPUT.PUT_LINE('  Errors: ' || v_error_count);
    DBMS_OUTPUT.PUT_LINE('============================================');
    
    IF v_error_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('✓ All grants completed successfully!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('⚠ Some grants failed. Review errors above.');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- ============================================================================
-- Create public synonyms (optional - for easier access)
-- ============================================================================

PROMPT
PROMPT Creating public synonyms (optional)...
PROMPT

-- Note: This requires CREATE PUBLIC SYNONYM privilege
-- If you don't have this privilege, consumer schemas can create private synonyms

BEGIN
    DBMS_OUTPUT.PUT_LINE('Creating public synonyms...');
    
    BEGIN
        EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM  ai_vector_utx FOR AI.ai_vector_util';
        DBMS_OUTPUT.PUT_LINE('  ✓ Public synonym created for package');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ⚠ Could not create public synonym (may require DBA privileges)');
            DBMS_OUTPUT.PUT_LINE('    Consumer schemas should create private synonyms instead');
    END;
    
END;
/

-- ============================================================================
-- Instructions for Consumer Schemas
-- ============================================================================

PROMPT
PROMPT ============================================
PROMPT Instructions for Consumer Schemas
PROMPT ============================================
PROMPT
PROMPT Each consumer schema should create a private synonym:
PROMPT
PROMPT   CREATE OR REPLACE SYNONYM ai_vector_utx
PROMPT   FOR AI.ai_vector_util;
PROMPT
PROMPT Then they can call functions directly:
PROMPT

select vector(AI.ai_vector_util.generate_embedding('بسم الله الرحمن الرحيم')) from dual;
select vector( ai_vector_utx.generate_embedding('my text'))  from dual;
select vector(AI.ai_vector_util.generate_embedding('my text')) from dual;

PROMPT ============================================
PROMPT

-- ============================================================================
-- Verify Grants
-- ============================================================================

PROMPT
PROMPT Verifying grants...
PROMPT

SELECT 
    grantee,
    table_name,
    privilege,
    grantable
FROM user_tab_privs
WHERE table_name IN (
    'AI_VECTOR_UTIL',
    'AI_MODEL_REGISTRY_V',
    'AI_DAILY_USAGE_BY_SCHEMA_V',
    'AI_REALTIME_USAGE_V',
    'AI_ERROR_SUMMARY_V',
    'AI_MODEL_HEALTH_V'
)
ORDER BY grantee, table_name;

PROMPT
PROMPT ============================================
PROMPT Grant script completed
PROMPT ============================================
