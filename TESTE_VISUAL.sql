-- DIAGNÓSTICO VISUAL (Retorna Tabela)
WITH check_data AS (
    SELECT 
        u.plano_mensal as plano,
        (SELECT COUNT(*) FROM users_alunos WHERE id_academia = u.id) as total_alunos,
        CASE 
            WHEN u.plano_mensal ILIKE 'Prata' THEN 200
            WHEN u.plano_mensal ILIKE 'Ouro' THEN 500
            WHEN u.plano_mensal ILIKE 'Platina' THEN 999999
            ELSE 200 
        END as limite
    FROM users_adm u
    WHERE u.id = 'f954d130-a6ad-4d1b-a61f-c92625f4de18'
)
SELECT 
    plano as "Plano Atual",
    total_alunos as "Alunos Cadastrados",
    limite as "Limite do Plano",
    (limite - total_alunos) as "Vagas Restantes",
    CASE 
        WHEN total_alunos >= limite THEN 'BLOQUEADO (Cheio)' 
        ELSE 'LIBERADO (Tem Vagas)' 
    END as "Status do Sistema"
FROM check_data;
