
----grant to user DB schema user which wants to access the ai embedding  model
DECLARE
    TYPE t_schema_array IS TABLE OF VARCHAR2(30);
    v_consumer_schemas t_schema_array;
    v_grant_count NUMBER := 0;
    v_error_count NUMBER := 0;
BEGIN
    -- Define all consumer schemas
    v_consumer_schemas := t_schema_array(
        'SCHMEA1' --<<<<replace  db schema or user that uses the vector model>>>>>>>>
         
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
