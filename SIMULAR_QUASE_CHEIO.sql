-- SCRIPT DE SIMULAÇÃO DE QUASE LOTAÇÃO (Mock Data)
-- Este script insere 199 alunos "fantasmas" para a academia f954d130-a6ad-4d1b-a61f-c92625f4de18
-- para permitir o teste de atingimento de limite.

DO $$
DECLARE
    v_academy_id UUID := 'f954d130-a6ad-4d1b-a61f-c92625f4de18';
    i INTEGER;
    v_limit INTEGER;
    v_current_count INTEGER;
BEGIN
    RAISE NOTICE '==================================================';
    RAISE NOTICE '🚀 INICIANDO POPULAÇÃO DE TESTE (199 ALUNOS)';
    RAISE NOTICE '==================================================';

    -- 1. Limpar mocks anteriores (por segurança)
    DELETE FROM users_alunos 
    WHERE id_academia = v_academy_id 
    AND email LIKE 'mock_student_%@spartan.test';

    -- 2. Verificar quantos alunos reais existem
    SELECT COUNT(*) INTO v_current_count FROM users_alunos WHERE id_academia = v_academy_id;

    -- 3. Calcular quantos faltam para chegar em 199
    -- Se já tiver mais que 199, aborta
    IF v_current_count >= 199 THEN
        RAISE NOTICE '⚠️ A academia já possui % alunos. Não é possível rodar o script de 199 mockados.', v_current_count;
        RETURN;
    END IF;

    -- Inserir alunos até completar 199
    FOR i IN (v_current_count + 1)..199 LOOP
        INSERT INTO users_alunos (
            id, -- Gerar UUID aleatório
            id_academia,
            created_by_admin_id,
            nome,
            email,
            telefone,
            role,
            is_blocked,
            created_at
        ) VALUES (
            gen_random_uuid(),
            v_academy_id,
            v_academy_id, -- Admin mockado
            'Aluno Mock ' || i,
            'mock_student_' || i || '@spartan.test',
            '(00) 00000-0000',
            'student',
            false,
            NOW()
        );
    END LOOP;

    RAISE NOTICE '✅ POPULAÇÃO CONCLUÍDA! A academia agora tem 199 alunos.';
    RAISE NOTICE '--------------------------------------------------';
    RAISE NOTICE '📋 PRÓXIMOS PASSOS NO APP (Teste Local):';
    RAISE NOTICE '1. Cadastre o Aluno nº 200 (Deve funcionar ✅).';
    RAISE NOTICE '   - Objetivo: Ver se o POPUP aparece APÓS o sucesso.';
    RAISE NOTICE '2. Tente cadastrar o Aluno nº 201 (Deve falhar ❌).';
    RAISE NOTICE '   - Objetivo: Ver se bloqueia.';
    RAISE NOTICE '==================================================';

END $$;
