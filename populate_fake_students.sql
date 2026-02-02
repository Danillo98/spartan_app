-- SCRIPT PARA POPULAR 499 ALUNOS FAKE
-- ACADEMIA ESPECÍFICA: f954d130-a6ad-4d1b-a61f-c92625f4de18

DO $$
DECLARE
    v_id_academia UUID := 'f954d130-a6ad-4d1b-a61f-c92625f4de18'; -- ID fixo solicitado
    v_count_needed INTEGER;
    v_current_count INTEGER;
BEGIN
    RAISE NOTICE 'Populando alunos para a academia ID: %', v_id_academia;

    -- 1. Quantos alunos já tem?
    SELECT COUNT(*) INTO v_current_count FROM users_alunos WHERE id_academia = v_id_academia;
    
    -- 2. Quantos faltam para chegar em 499?
    v_count_needed := 499 - v_current_count;

    IF v_count_needed <= 0 THEN
        RAISE NOTICE 'A academia já tem % alunos (>= 499). Nada a fazer.', v_current_count;
        RETURN;
    END IF;

    RAISE NOTICE 'Inserindo % alunos fakes...', v_count_needed;

    -- 3. Inserir alunos fakes (Incluindo created_by_admin_id)
    INSERT INTO users_alunos (id, id_academia, academia, created_by_admin_id, nome, email, telefone, data_nascimento)
    SELECT 
        gen_random_uuid(), -- ID do aluno
        v_id_academia,     -- Coluna id_academia
        v_id_academia,     -- Coluna academia
        v_id_academia,     -- Coluna created_by_admin_id
        'Aluno Fake ' || i,
        'fake.student.' || v_id_academia || '.' || i || '@test.com',
        '11999999999',
        '2000-01-01'
    FROM generate_series(v_current_count + 1, 499) AS i;

    RAISE NOTICE 'Sucesso! Agora a academia tem 499 alunos.';
END $$;
