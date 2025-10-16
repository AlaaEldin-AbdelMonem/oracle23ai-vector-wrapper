-- 1. Create private synonym from the db schema user that you want to access:

CREATE SYNONYM ai_vector_utx FOR AI.ai_vector_util;


-- 2. Test it
SELECT ai_vector_utx.health_check() FROM dual;


-- 3. Generate your first embedding
SELECT ai_vector_utx.generate_embedding('Hello AI!') FROM dual;
