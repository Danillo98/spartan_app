-- Inserir 196 alunos fictícios para teste de limite do plano
-- Academia ID: aeb5b282-6a87-4314-a9d8-02693bf77ed2

INSERT INTO public.users_alunos (
    id,
    id_academia,
    academia, -- Nome da Academia (Campo obrigatório)
    created_by_admin_id, -- Admin criador (Campo obrigatório)
    nome,
    email,
    created_at,
    is_blocked,
    email_verified,
    updated_at
)
SELECT
    gen_random_uuid(), -- Gera um ID único para cada aluno
    'aeb5b282-6a87-4314-a9d8-02693bf77ed2', -- ID da Academia Alvo
    'Academia de Teste', -- Nome fictício para a academia
    (SELECT id FROM public.users_adm LIMIT 1), -- Usa o primeiro admin disponível como criador
    'Aluno Teste ' || i, -- Nome sequencial
    'teste_limit_' || i || '_' || floor(random() * 10000)::text || '@exemplo.com', -- Email único aleatório
    NOW(),
    false, -- Não is_blocked
    true,  -- email_verified
    NOW()
FROM generate_series(1, 196) AS i;

-- Verificar a contagem após a inserção
SELECT count(*) as total_alunos 
FROM public.users_alunos 
WHERE id_academia = 'aeb5b282-6a87-4314-a9d8-02693bf77ed2';
