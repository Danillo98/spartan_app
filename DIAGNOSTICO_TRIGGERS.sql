-- DIAGNÓSTICO DE TRIGGERS
-- Vamos descobrir quem é a trigger culpada em auth.users

SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'users'
AND event_object_schema = 'auth';

-- Tentar ver o código da função associada (mais complexo, mas vamos tentar pelo nome primeiro)
