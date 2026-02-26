-- ============================================
-- SQL DE CORREÇÃO CIRÚRGICA (OPÇÃO A)
-- Restaurar payment_due_day e unificar lógica
-- ============================================

DO $$ 
BEGIN
    -- 1. Se a coluna payment_due existir (a intrusa), vamos mover os dados e restaurar o padrão
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users_alunos' AND column_name='payment_due') THEN
        
        -- Garante que payment_due_day existe (deve existir, mas por segurança)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users_alunos' AND column_name='payment_due_day') THEN
            ALTER TABLE public.users_alunos ADD COLUMN payment_due_day INT DEFAULT 10;
        END IF;

        -- Copia os dados da intrusa para a oficial
        UPDATE public.users_alunos SET payment_due_day = payment_due WHERE payment_due IS NOT NULL;

        -- Remove a intrusa
        ALTER TABLE public.users_alunos DROP COLUMN payment_due;
        
    END IF;
END $$;

-- 2. Atualizar a Função de Cálculo Master (agora usando payment_due_day)
CREATE OR REPLACE FUNCTION public.fn_calculate_student_status(p_student_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_created_at TIMESTAMP;
    v_payment_due INT;
    v_grace_period INT;
    v_paid_count INT;
    v_months_since_entry INT;
    v_now TIMESTAMP := NOW();
    v_status TEXT := 'pending';
BEGIN
    -- Obter dados do aluno (Usando a coluna oficial e carência)
    SELECT created_at, COALESCE(payment_due_day, 10), COALESCE(grace_period, 3)
    INTO v_created_at, v_payment_due, v_grace_period
    FROM public.users_alunos
    WHERE id = p_student_id;

    IF NOT FOUND THEN RETURN 'unknown'; END IF;

    -- Contar pagamentos realizados
    SELECT COUNT(*)
    INTO v_paid_count
    FROM public.financial_transactions
    WHERE related_user_id = p_student_id
      AND type = 'income'
      AND related_user_role = 'student';

    -- Calcular meses desde a entrada (Incluindo o mês atual)
    v_months_since_entry := (EXTRACT(YEAR FROM v_now) - EXTRACT(YEAR FROM v_created_at)) * 12 
                          + (EXTRACT(MONTH FROM v_now) - EXTRACT(MONTH FROM v_created_at)) + 1;

    IF v_months_since_entry < 1 THEN v_months_since_entry := 1; END IF;

    -- Lógica de Status (Respeitando a Carência de 3 dias no mês atual)
    IF v_paid_count >= v_months_since_entry THEN
        v_status := 'paid';
    ELSIF v_paid_count < v_months_since_entry - 1 THEN
        -- Deve meses anteriores (Bloqueio Automático)
        v_status := 'overdue';
    ELSE
        -- Deve apenas o mês atual -> Verifica Carência
        IF EXTRACT(DAY FROM v_now) > (v_payment_due + v_grace_period) THEN
            v_status := 'overdue';
        ELSE
            v_status := 'pending';
        END IF;
    END IF;

    RETURN v_status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Atualizar Triggers para vigiar a coluna correta
DROP TRIGGER IF EXISTS tr_refresh_status_on_student_change ON public.users_alunos;
CREATE TRIGGER tr_refresh_status_on_student_change
AFTER UPDATE OF payment_due_day, created_at, grace_period ON public.users_alunos
FOR EACH ROW EXECUTE FUNCTION public.fn_trigger_refresh_student_status();

-- 4. Corrigir a RPC create_user_v4 para usar a coluna oficial
CREATE OR REPLACE FUNCTION public.create_user_v4(
    p_email TEXT,
    p_password TEXT,
    p_metadata JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_user_id UUID;
    user_role TEXT;
    user_name TEXT;
    user_phone TEXT;
    user_academia TEXT;
    user_id_academia UUID;
    user_cnpj TEXT;
    v_payment_due_day INT;
    v_grace_period INT;
    is_paid_current_month BOOLEAN;
    next_due_date DATE;
    created_by_admin_id UUID;
BEGIN
    -- Extrair dados do metadata
    user_role := p_metadata->>'role';
    user_name := p_metadata->>'name';
    user_phone := p_metadata->>'phone';
    user_academia := p_metadata->>'academia';
    user_id_academia := (p_metadata->>'id_academia')::UUID;
    user_cnpj := p_metadata->>'cnpj_academia';
    v_payment_due_day := COALESCE((p_metadata->>'paymentDueDay')::INT, 10);
    v_grace_period := COALESCE((p_metadata->>'gracePeriod')::INT, 3);
    is_paid_current_month := COALESCE((p_metadata->>'isPaidCurrentMonth')::BOOLEAN, FALSE);
    created_by_admin_id := (p_metadata->>'created_by_admin_id')::UUID;

    -- VALIDAÇÃO CRÍTICA
    IF user_id_academia IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'id_academia é obrigatório');
    END IF;

    -- 1. Criar usuário no Auth
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) VALUES (
        '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', p_email, crypt(p_password, gen_salt('bf')), NOW(),
        jsonb_build_object('provider', 'email', 'providers', ARRAY['email']), p_metadata, NOW(), NOW()
    ) RETURNING id INTO new_user_id;

    -- 2. Registro na tabela pública
    IF user_role = 'nutritionist' THEN
        INSERT INTO public.users_nutricionista (id, nome, email, telefone, academia, cnpj_academia, id_academia, created_by_admin_id, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_academia, user_cnpj, user_id_academia, created_by_admin_id, TRUE, NOW(), NOW());
    ELSIF user_role = 'trainer' THEN
        INSERT INTO public.users_personal (id, nome, email, telefone, academia, cnpj_academia, id_academia, created_by_admin_id, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_academia, user_cnpj, user_id_academia, created_by_admin_id, TRUE, NOW(), NOW());
    ELSIF user_role = 'student' THEN
        -- Calcular próximo vencimento
        next_due_date := make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT, v_payment_due_day);
        IF next_due_date < CURRENT_DATE THEN next_due_date := next_due_date + INTERVAL '1 month'; END IF;
        
        INSERT INTO public.users_alunos (
            id, nome, email, telefone, academia, cnpj_academia, id_academia, created_by_admin_id, email_verified, 
            payment_due_day, grace_period, is_paid_current_month, next_payment_due, created_at, updated_at
        ) VALUES (
            new_user_id, user_name, p_email, user_phone, user_academia, user_cnpj, user_id_academia, created_by_admin_id, TRUE, 
            v_payment_due_day, v_grace_period, is_paid_current_month, next_due_date, NOW(), NOW()
        );
    END IF;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Usuário criado com sucesso', 'user_id', new_user_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Erro: ' || SQLERRM);
END;
$$;

-- 5. Sincronização Final
UPDATE public.users_alunos SET status_financeiro = public.fn_calculate_student_status(id);

SELECT '✅ Sistema restaurado para payment_due_day com sucesso!' as status;
