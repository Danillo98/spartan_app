-- ============================================
-- CORREÇÃO CIRÚRGICA V2.4.6 - REMOÇÃO DE CARÊNCIA E FIX SCHEMA
-- ============================================

-- 1. Garantir que a estrutura de users_alunos está correta
-- Remover carência (se ainda existir)
ALTER TABLE public.users_alunos DROP COLUMN IF EXISTS grace_period CASCADE;

-- Garantir colunas essenciais para o funcionamento do sistema
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS payment_due_day INT DEFAULT 10;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS next_payment_due DATE;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS data_nascimento DATE;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS status_financeiro TEXT DEFAULT 'pending';

-- 2. Atualizar Função de Cálculo de Status (VENCIMENTO ESTRITO)
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
    -- Obter dados do aluno
    SELECT created_at, COALESCE(payment_due_day, 10)
    INTO v_created_at, v_payment_due
    FROM public.users_alunos
    WHERE id = p_student_id;

    IF NOT FOUND THEN RETURN 'unknown'; END IF;

    -- Contar pagamentos
    SELECT COUNT(*) INTO v_paid_count
    FROM public.financial_transactions
    WHERE related_user_id = p_student_id
      AND type = 'income'
      AND (category = 'Mensalidade' OR category = 'income');

    -- Meses de vida no sistema
    v_months_since_entry := (EXTRACT(YEAR FROM v_now) - EXTRACT(YEAR FROM v_created_at)) * 12 
                          + (EXTRACT(MONTH FROM v_now) - EXTRACT(MONTH FROM v_created_at)) + 1;

    IF v_months_since_entry < 1 THEN v_months_since_entry := 1; END IF;

    -- Lógica de Status (ESTRITA: Hoje > Vencimento = BLOQUEADO)
    IF v_paid_count >= v_months_since_entry THEN
        v_status := 'paid';
    ELSIF v_paid_count < v_months_since_entry - 1 THEN
        v_status := 'overdue';
    ELSE
        -- No mês atual: se hoje > dia de vencimento -> BLOQUEIA
        IF EXTRACT(DAY FROM v_now) > v_payment_due THEN
            v_status := 'overdue';
        ELSE
            v_status := 'pending';
        END IF;
    END IF;

    RETURN v_status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Blindar a RPC create_user_v4 (Compatível com next_payment_due)
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
    -- Extrair do metadata
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

    -- Validação
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

    -- 2. Inserir Aluno (com next_payment_due garantido)
    IF user_role = 'student' THEN
        -- Calcular próximo vencimento NOMINAL
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
    ELSIF user_role = 'nutritionist' THEN
        INSERT INTO public.users_nutricionista (id, nome, email, telefone, academia, cnpj_academia, id_academia, created_by_admin_id, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_academia, user_cnpj, user_id_academia, v_created_by_admin_id, TRUE, NOW(), NOW());
    ELSIF user_role = 'trainer' THEN
        INSERT INTO public.users_personal (id, nome, email, telefone, academia, cnpj_academia, id_academia, created_by_admin_id, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_academia, user_cnpj, user_id_academia, v_created_by_admin_id, TRUE, NOW(), NOW());
    END IF;

    -- Recarregar status financeiro imediatamente
    UPDATE public.users_alunos SET status_financeiro = public.fn_calculate_student_status(new_user_id) WHERE id = new_user_id;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Usuário criado com sucesso', 'user_id', new_user_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Erro no Banco: ' || SQLERRM);
END;
$$;

-- 4. Forçar RECARGA DO SCHEMA (Para resolver erro de Querying Schema no App)
NOTIFY pgrst, 'reload schema';

SELECT '✅ Sistema Spartans v2.4.6 Estabilizado: Carência DELETADA e NextPaymentDue RESTAURADO.' as status;
