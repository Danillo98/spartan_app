-- SCRIPT DE SIMULAÇÃO (V3 - CORRIGIDO e ROBUSTO)
-- Insere alunos até atingir 199, respeitando as constraints NOT NULL

DO $$
DECLARE
    v_academy_id UUID := 'f954d130-a6ad-4d1b-a61f-c92625f4de18';
    v_nome_academia TEXT;
    v_cnpj_academia TEXT;
    i INTEGER;
    v_current_count INTEGER;
BEGIN
    RAISE NOTICE '==================================================';
    RAISE NOTICE '🚀 INICIANDO POPULAÇÃO DE TESTE (199 ALUNOS)';
    
    -- 1. Obter dados obrigatórios da academia para evitar erro NOT NULL
    SELECT academia, cnpj_academia 
    INTO v_nome_academia, v_cnpj_academia
    FROM users_adm 
    WHERE id = v_academy_id;

    IF v_nome_academia IS NULL THEN
        RAISE EXCEPTION 'Academia não encontrada ou dados incompletos!';
    END IF;

    -- 2. Limpar mocks anteriores
    DELETE FROM users_alunos 
    WHERE id_academia = v_academy_id 
    AND email LIKE 'mock_student_%@spartan.test';

    -- 3. Verificar contagem atual
    SELECT COUNT(*) INTO v_current_count FROM users_alunos WHERE id_academia = v_academy_id;

    -- 4. Loop de Inserção
    IF v_current_count >= 199 THEN
        RAISE NOTICE '⚠️ A academia já possui % alunos. Abortando.', v_current_count;
        RETURN;
    END IF;

    FOR i IN (v_current_count + 1)..199 LOOP
        INSERT INTO users_alunos (
            id, 
            id_academia,
            created_by_admin_id,
            nome,
            email,
            telefone,
            academia,      -- Obrigatório
            cnpj_academia, -- Obrigatório
            is_blocked,
            created_at,
            updated_at
        ) VALUES (
            gen_random_uuid(),
            v_academy_id,
            v_academy_id, 
            'Aluno Mock ' || i,
            'mock_student_' || i || '@spartan.test',
            '(00) 00000-0000',
            v_nome_academia, -- Preenchendo
            v_cnpj_academia, -- Preenchendo
            false,
            NOW(),
            NOW()
        );
    END LOOP;

    RAISE NOTICE '✅ SUCESSO! Agora temos 199 alunos.';
END $$;
