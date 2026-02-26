-- ============================================
-- SQL DE ESTABILIZAÇÃO DEFINITIVA v2.4.6
-- RESTAURAÇÃO DE COLUNAS CRÍTICAS (Academia e CNPJ)
-- REMOÇÃO TOTAL DE CARÊNCIA + SUPORTE DATA NASCIMENTO
-- ============================================

-- 1. Garantir que as colunas existem na tabela de alunos
ALTER TABLE public.users_alunos DROP COLUMN IF EXISTS grace_period CASCADE;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS payment_due_day INT DEFAULT 10;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS next_payment_due DATE;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS data_nascimento DATE;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS status_financeiro TEXT DEFAULT 'pending';
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS academia TEXT;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS cnpj_academia TEXT;

-- 2. Atualizar RPC create_user_v4
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
    v_birth_date DATE;
    v_next_due_date DATE;
    v_created_by_admin_id UUID;
    v_is_paid_current_month BOOLEAN;
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
    v_created_by_admin_id := (p_metadata->>'created_by_admin_id')::UUID;
    v_is_paid_current_month := COALESCE((p_metadata->>'isPaidCurrentMonth')::BOOLEAN, FALSE);

    -- Se não veio created_by_admin_id no metadata, tenta pegar o id_academia (comportamento v2.3.0)
    IF v_created_by_admin_id IS NULL THEN
        v_created_by_admin_id := user_id_academia;
    END IF;

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

    -- 2. Registro na tabela pública correspondente
    IF user_role = 'student' THEN
        -- Calcular próximo vencimento NOMINAL (Sem carência)
        IF v_payment_due_day IS NOT NULL THEN
            v_next_due_date := make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT, v_payment_due_day);
            IF v_next_due_date < CURRENT_DATE THEN 
                v_next_due_date := v_next_due_date + INTERVAL '1 month'; 
            END IF;
        END IF;

        INSERT INTO public.users_alunos (
            id, nome, email, telefone, academia, cnpj_academia, id_academia, 
            created_by_admin_id, email_verified, payment_due_day, 
            next_payment_due, data_nascimento, created_at, updated_at, is_paid_current_month
        ) VALUES (
            new_user_id, user_name, p_email, user_phone, COALESCE(user_academia, 'Spartan Gym'), user_cnpj, user_id_academia, 
            v_created_by_admin_id, TRUE, v_payment_due_day, 
            v_next_due_date, v_birth_date, NOW(), NOW(), v_is_paid_current_month
        );
    ELSIF user_role = 'nutritionist' THEN
        INSERT INTO public.users_nutricionista (id, nome, email, telefone, academia, cnpj_academia, id_academia, created_by_admin_id, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, COALESCE(user_academia, 'Spartan Gym'), user_cnpj, user_id_academia, v_created_by_admin_id, TRUE, NOW(), NOW());
    ELSIF user_role = 'trainer' THEN
        INSERT INTO public.users_personal (id, nome, email, telefone, academia, cnpj_academia, id_academia, created_by_admin_id, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, COALESCE(user_academia, 'Spartan Gym'), user_cnpj, user_id_academia, v_created_by_admin_id, TRUE, NOW(), NOW());
    END IF;

    -- Resetar Cache
    NOTIFY pgrst, 'reload schema';

    RETURN jsonb_build_object('success', TRUE, 'message', 'Usuário criado com sucesso', 'user_id', new_user_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Erro no Banco: ' || SQLERRM);
END;
$$;
