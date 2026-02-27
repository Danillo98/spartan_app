-- ============================================================
-- FIX DEFINITIVO: create_user_v4 sem cnpj_academia
-- v2.5.5 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Corrige a RPC removendo referências à coluna cnpj_academia
-- das tabelas users_nutricionista e users_personal (que foram
-- removidas pelos scripts FINAL_CLEANUP_CNPJ e CASCADE_CLEANUP_CNPJ).
-- Também adiciona tratamento de erro isolado por tabela.
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
    -- Extrair dados do metadata
    user_role             := p_metadata->>'role';
    user_name             := p_metadata->>'name';
    user_phone            := COALESCE(p_metadata->>'phone', '');
    user_academia         := COALESCE(p_metadata->>'academia', 'Academia');
    user_id_academia      := (p_metadata->>'id_academia')::UUID;
    v_payment_due_day     := (p_metadata->>'paymentDueDay')::INT;
    v_birth_date          := (p_metadata->>'birthDate')::DATE;
    v_created_by_admin_id := (p_metadata->>'created_by_admin_id')::UUID;
    v_is_paid_current_month := COALESCE((p_metadata->>'isPaidCurrentMonth')::BOOLEAN, FALSE);

    -- Fallback: se não veio created_by_admin_id, usa id_academia
    IF v_created_by_admin_id IS NULL THEN
        v_created_by_admin_id := user_id_academia;
    END IF;

    -- Validações obrigatórias
    IF user_id_academia IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'id_academia é obrigatório');
    END IF;

    IF user_role NOT IN ('student', 'nutritionist', 'trainer') THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'role inválido: ' || COALESCE(user_role, 'NULL'));
    END IF;

    -- =============================================
    -- PASSO 1: Criar no Auth (com email confirmado)
    -- =============================================
    BEGIN
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at, confirmation_sent_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            p_email,
            crypt(p_password, gen_salt('bf')),
            NOW(),
            jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
            p_metadata,
            NOW(), NOW(), NOW()
        ) RETURNING id INTO new_user_id;
    EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Email já cadastrado');
    END;

    -- =============================================
    -- PASSO 2: Inserir na tabela pública correta
    -- (SEM cnpj_academia - coluna foi removida)
    -- =============================================
    IF user_role = 'student' THEN
        -- Calcular vencimento
        IF v_payment_due_day IS NOT NULL THEN
            v_next_due_date := make_date(
                EXTRACT(YEAR FROM CURRENT_DATE)::INT,
                EXTRACT(MONTH FROM CURRENT_DATE)::INT,
                v_payment_due_day
            );
            IF v_next_due_date < CURRENT_DATE THEN
                v_next_due_date := v_next_due_date + INTERVAL '1 month';
            END IF;
        END IF;

        BEGIN
            INSERT INTO public.users_alunos (
                id, nome, email, telefone, academia, id_academia,
                created_by_admin_id, email_verified, payment_due_day,
                next_payment_due, data_nascimento,
                is_paid_current_month, is_blocked, created_at, updated_at
            ) VALUES (
                new_user_id, user_name, p_email, user_phone, user_academia, user_id_academia,
                v_created_by_admin_id, TRUE, v_payment_due_day,
                v_next_due_date, v_birth_date,
                v_is_paid_current_month, FALSE, NOW(), NOW()
            );
        EXCEPTION WHEN OTHERS THEN
            -- Desfaz o usuário do auth para não deixar órfão
            DELETE FROM auth.users WHERE id = new_user_id;
            RETURN jsonb_build_object('success', FALSE, 'message', 'Erro ao criar aluno: ' || SQLERRM);
        END;

    ELSIF user_role = 'nutritionist' THEN
        BEGIN
            INSERT INTO public.users_nutricionista (
                id, nome, email, telefone, academia, id_academia,
                created_by_admin_id, email_verified, is_blocked,
                created_at, updated_at
            ) VALUES (
                new_user_id, user_name, p_email, user_phone, user_academia, user_id_academia,
                v_created_by_admin_id, TRUE, FALSE,
                NOW(), NOW()
            );
        EXCEPTION WHEN OTHERS THEN
            DELETE FROM auth.users WHERE id = new_user_id;
            RETURN jsonb_build_object('success', FALSE, 'message', 'Erro ao criar nutricionista: ' || SQLERRM);
        END;

    ELSIF user_role = 'trainer' THEN
        BEGIN
            INSERT INTO public.users_personal (
                id, nome, email, telefone, academia, id_academia,
                created_by_admin_id, email_verified, is_blocked,
                created_at, updated_at
            ) VALUES (
                new_user_id, user_name, p_email, user_phone, user_academia, user_id_academia,
                v_created_by_admin_id, TRUE, FALSE,
                NOW(), NOW()
            );
        EXCEPTION WHEN OTHERS THEN
            DELETE FROM auth.users WHERE id = new_user_id;
            RETURN jsonb_build_object('success', FALSE, 'message', 'Erro ao criar personal: ' || SQLERRM);
        END;
    END IF;

    -- Notificar PostgREST
    NOTIFY pgrst, 'reload schema';

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Usuário criado com sucesso',
        'user_id', new_user_id
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Erro inesperado: ' || SQLERRM);
END;
$$;

-- Garantir permissões
GRANT EXECUTE ON FUNCTION public.create_user_v4(TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_user_v4(TEXT, TEXT, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_user_v4(TEXT, TEXT, JSONB) TO anon;

NOTIFY pgrst, 'reload schema';
SELECT '✅ create_user_v4 corrigida! Sem cnpj_academia. Rollback automático em caso de erro.' as status;
