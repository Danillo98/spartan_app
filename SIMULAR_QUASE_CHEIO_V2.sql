-- SCRIPT DE SIMULAÇÃO (CORRIGIDO)
-- Removemos a coluna 'role' que não existe na tabela users_alunos

DO $$
DECLARE
    v_academy_id UUID := 'f954d130-a6ad-4d1b-a61f-c92625f4de18';
    i INTEGER;
    v_limit INTEGER;
    v_current_count INTEGER;
BEGIN
    RAISE NOTICE '==================================================';
    RAISE NOTICE '🚀 INICIANDO POPULAÇÃO DE TESTE (199 ALUNOS)';
    
    -- 1. Limpar mocks anteriores
    DELETE FROM users_alunos 
    WHERE id_academia = v_academy_id 
    AND email LIKE 'mock_student_%@spartan.test';

    -- 2. Verificar quantos alunos reais existem
    SELECT COUNT(*) INTO v_current_count FROM users_alunos WHERE id_academia = v_academy_id;

    -- 3. Calcular
    IF v_current_count >= 199 THEN
        RAISE NOTICE '⚠️ A academia já possui % alunos. Abortando.', v_current_count;
        RETURN;
    END IF;

    -- Inserir alunos até 199
    FOR i IN (v_current_count + 1)..199 LOOP
        INSERT INTO users_alunos (
            id, 
            id_academia,
            created_by_admin_id,
            nome,
            email,
            telefone,
            is_blocked,
            created_at
        ) VALUES (
            gen_random_uuid(),
            v_academy_id,
            v_academy_id, 
            'Aluno Mock ' || i,
            'mock_student_' || i || '@spartan.test',
            '(00) 00000-0000',
            false,
            NOW()
        );
    END LOOP;

    RAISE NOTICE '✅ SUCESSO! Agora temos 199 alunos.';
END $$;
