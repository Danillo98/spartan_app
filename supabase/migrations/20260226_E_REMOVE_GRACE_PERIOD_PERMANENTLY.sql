-- ============================================
-- REMOÇÃO TOTAL E PERMANENTE DA CARÊNCIA (3 Dias)
-- Versão: 2.4.5 - Restauração ao Vencimento Estrito
-- ============================================

-- 1. Remover coluna de carência da tabela de alunos
ALTER TABLE public.users_alunos DROP COLUMN IF EXISTS grace_period CASCADE;

-- 2. Atualizar Função Master de Cálculo de Status (Sem Carência)
CREATE OR REPLACE FUNCTION public.fn_calculate_student_status(p_student_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_created_at TIMESTAMP;
    v_payment_due INT;
    v_paid_count INT;
    v_months_since_entry INT;
    v_now TIMESTAMP := NOW();
    v_status TEXT := 'pending';
BEGIN
    -- Obter dados do aluno (Somente Vencimento)
    SELECT created_at, COALESCE(payment_due_day, 10)
    INTO v_created_at, v_payment_due
    FROM public.users_alunos
    WHERE id = p_student_id;

    IF NOT FOUND THEN RETURN 'unknown'; END IF;

    -- Contar pagamentos realizados (Mensalidades)
    SELECT COUNT(*) INTO v_paid_count
    FROM public.financial_transactions
    WHERE related_user_id = p_student_id
      AND type = 'income'
      AND (category = 'Mensalidade' OR category = 'income');

    -- Calcular meses desde a entrada
    v_months_since_entry := (EXTRACT(YEAR FROM v_now) - EXTRACT(YEAR FROM v_created_at)) * 12 
                          + (EXTRACT(MONTH FROM v_now) - EXTRACT(MONTH FROM v_created_at)) + 1;

    IF v_months_since_entry < 1 THEN v_months_since_entry := 1; END IF;

    -- Lógica de Status (ESTRITA)
    IF v_paid_count >= v_months_since_entry THEN
        v_status := 'paid';
    ELSIF v_paid_count < v_months_since_entry - 1 THEN
        v_status := 'overdue';
    ELSE
        -- No mês atual: se hoje > dia de vencimento -> OVERDUE
        IF EXTRACT(DAY FROM v_now) > v_payment_due THEN
            v_status := 'overdue';
        ELSE
            v_status := 'pending';
        END IF;
    END IF;

    RETURN v_status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Atualizar RPC create_user_v4 (Remover carência do INSERT)
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
    v_is_paid_current_month BOOLEAN;
    v_birth_date DATE;
    v_next_due_date DATE;
    v_created_by_admin_id UUID;
BEGIN
    -- Extrair dados do metadata
    user_role := p_metadata->>'role';
    user_name := p_metadata->>'name';
    user_phone := p_metadata->>'phone';
    user_academia := p_metadata->>'academia';
    user_id_academia := (p_metadata->>'id_academia')::UUID;
    user_cnpj := p_metadata->>'cnpj_academia';
    v_payment_due_day := (p_metadata->>'paymentDueDay')::INT;
    v_birth_date := (p_metadata->>'birthDate')::DATE;
    v_is_paid_current_month := COALESCE((p_metadata->>'isPaidCurrentMonth')::BOOLEAN, FALSE);
    v_created_by_admin_id := (p_metadata->>'created_by_admin_id')::UUID;

    -- Validação: id_academia é obrigatório
    IF user_id_academia IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'id_academia é obrigatório');
    END IF;

    -- 1. Criar no Auth
    BEGIN
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, 
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_sent_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', p_email, 
            crypt(p_password, gen_salt('bf')), NOW(),
            jsonb_build_object('provider', 'email', 'providers', ARRAY['email']), p_metadata, NOW(), NOW(), NOW()
        ) RETURNING id INTO new_user_id;
    EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Email já cadastrado');
    END;

    -- 2. Registro na tabela pública (Sem grace_period)
    IF user_role = 'nutritionist' THEN
        INSERT INTO public.users_nutricionista (id, nome, email, telefone, academia, cnpj_academia, id_academia, created_by_admin_id, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_academia, user_cnpj, user_id_academia, v_created_by_admin_id, TRUE, NOW(), NOW());
    ELSIF user_role = 'trainer' THEN
        INSERT INTO public.users_personal (id, nome, email, telefone, academia, cnpj_academia, id_academia, created_by_admin_id, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_academia, user_cnpj, user_id_academia, v_created_by_admin_id, TRUE, NOW(), NOW());
    ELSIF user_role = 'student' THEN
        -- Calcular próximo vencimento para visualização
        IF v_payment_due_day IS NOT NULL THEN
            v_next_due_date := make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT, v_payment_due_day);
            IF v_next_due_date < CURRENT_DATE THEN v_next_due_date := v_next_due_date + INTERVAL '1 month'; END IF;
        END IF;

        INSERT INTO public.users_alunos (
            id, nome, email, telefone, academia, cnpj_academia, id_academia, created_by_admin_id, email_verified, 
            payment_due_day, is_paid_current_month, next_payment_due, data_nascimento, created_at, updated_at
        ) VALUES (
            new_user_id, user_name, p_email, user_phone, user_academia, user_cnpj, user_id_academia, v_created_by_admin_id, TRUE, 
            v_payment_due_day, v_is_paid_current_month, v_next_due_date, v_birth_date, NOW(), NOW()
        );
    END IF;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Usuário criado', 'user_id', new_user_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Erro: ' || SQLERRM);
END;
$$;

-- 4. Atualizar Trigger de Sincronização (Remover grace_period da escuta)
DROP TRIGGER IF EXISTS tr_refresh_status_on_student_change ON public.users_alunos;
CREATE TRIGGER tr_refresh_status_on_student_change
AFTER UPDATE OF payment_due_day, created_at ON public.users_alunos
FOR EACH ROW EXECUTE FUNCTION public.fn_trigger_refresh_student_status();

-- 5. Atualizar todos os alunos para o novo status estrito
UPDATE public.users_alunos SET status_financeiro = public.fn_calculate_student_status(id);

-- 6. Recarregar Schema Cache
NOTIFY pgrst, 'reload schema';

SELECT '✅ Carência REMOVIDA PERMANENTEMENTE. Sistema restaurado ao Vencimento Estrito!' as status;
