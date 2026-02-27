-- ============================================================
-- SCRIPT DE CADASTRO - DEFINITIVO
-- ============================================================
-- Se o count dá 0 no seu print, significa que o `create_user_v4`
-- falha silenciosamente (cai no bloco EXCEPTION WHEN OTHERS e
-- cancela). O problema é a coluna cnpj_academia nula ou outra restrição.
--
-- Esta versão é completamente segura. Se algo falhar, ele rola
-- de volta o Auth para o erro não ficar invisível, e fornece um
-- log limpo.
-- ============================================================

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
    v_payment_due_day INT;
    v_birth_date DATE;
    v_next_due_date DATE;
    v_created_by_admin_id UUID;
    v_is_paid_current_month BOOLEAN;
BEGIN
    -- Captura básica
    user_role := p_metadata->>'role';
    user_name := p_metadata->>'name';
    user_phone := p_metadata->>'phone';
    user_academia := COALESCE(p_metadata->>'academia', 'Academia');
    user_id_academia := (p_metadata->>'id_academia')::UUID;
    v_payment_due_day := (p_metadata->>'paymentDueDay')::INT;
    v_birth_date := (p_metadata->>'birthDate')::DATE;
    v_created_by_admin_id := (p_metadata->>'created_by_admin_id')::UUID;
    v_is_paid_current_month := COALESCE((p_metadata->>'isPaidCurrentMonth')::BOOLEAN, FALSE);

    IF v_created_by_admin_id IS NULL THEN
        v_created_by_admin_id := user_id_academia;
    END IF;

    -- 1. Cria usuário no Auth
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_sent_at
    ) VALUES (
        '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', p_email,
        crypt(p_password, gen_salt('bf')), NOW(),
        jsonb_build_object('provider', 'email', 'providers', ARRAY['email']), p_metadata, NOW(), NOW(), NOW()
    ) RETURNING id INTO new_user_id;

    -- 2. Insere na tabela Pública de acordo com o Role
    IF user_role = 'student' THEN
        -- Lógica de Vencimento
        IF v_payment_due_day IS NOT NULL THEN
            v_next_due_date := make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT, v_payment_due_day);
            IF v_next_due_date < CURRENT_DATE THEN
                v_next_due_date := v_next_due_date + INTERVAL '1 month';
            END IF;
        END IF;

        INSERT INTO public.users_alunos (
            id, nome, email, telefone, academia, id_academia,
            created_by_admin_id, email_verified, payment_due_day,
            next_payment_due, data_nascimento, created_at, updated_at, is_paid_current_month
        ) VALUES (
            new_user_id, user_name, p_email, user_phone, user_academia, user_id_academia,
            v_created_by_admin_id, TRUE, v_payment_due_day,
            v_next_due_date, v_birth_date, NOW(), NOW(), v_is_paid_current_month
        );

    ELSIF user_role = 'nutritionist' THEN
        INSERT INTO public.users_nutricionista (
            id, nome, email, telefone, academia, id_academia, created_by_admin_id, email_verified, created_at, updated_at
        ) VALUES (
            new_user_id, user_name, p_email, user_phone, user_academia, user_id_academia, v_created_by_admin_id, TRUE, NOW(), NOW()
        );

    ELSIF user_role = 'trainer' THEN
        INSERT INTO public.users_personal (
            id, nome, email, telefone, academia, id_academia, created_by_admin_id, email_verified, created_at, updated_at
        ) VALUES (
            new_user_id, user_name, p_email, user_phone, user_academia, user_id_academia, v_created_by_admin_id, TRUE, NOW(), NOW()
        );
    END IF;

    -- Notifica e Sucesso
    NOTIFY pgrst, 'reload schema';
    RETURN jsonb_build_object('success', TRUE, 'message', 'Usuário criado com sucesso', 'user_id', new_user_id);

EXCEPTION WHEN OTHERS THEN
    -- Em caso de erro na tabela pública (ex: null na coluna academia), desfaz o Auth (Rollback) 
    -- e retorna a mensagem real do erro para não ficar escondido
    DELETE FROM auth.users WHERE id = new_user_id;
    RETURN jsonb_build_object('success', FALSE, 'message', 'Erro Fatal ao Cadastrar: ' || SQLERRM);
END;
$$;
