DO $$
DECLARE
    v_academy_id UUID := '838604d9-bc4d-4259-b283-eede44f4f892';
    v_academy_name TEXT;
    v_count INT := 199;
BEGIN
    -- Buscar o nome da academia
    SELECT academia INTO v_academy_name FROM public.users_adm WHERE id = v_academy_id;
    
    -- Fallback se não encontrar
    IF v_academy_name IS NULL THEN
        v_academy_name := 'Academia Teste Load';
    END IF;

    INSERT INTO public.users_alunos (
        id,
        id_academia,
        academia,
        nome,
        email,
        telefone,
        created_by_admin_id,
        created_at,
        updated_at
    )
    SELECT
        gen_random_uuid(),
        v_academy_id,
        v_academy_name,
        'Aluno Teste ' || s.i,
        'aluno.teste.' || s.i || '@spartan.test',
        '11999999999',
        v_academy_id,
        NOW(),
        NOW()
    FROM generate_series(1, v_count) AS s(i);
    
    RAISE NOTICE 'Inseridos % alunos com sucesso para a academia % (%)', v_count, v_academy_name, v_academy_id;
END $$;
