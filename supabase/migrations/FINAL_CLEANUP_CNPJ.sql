-- ============================================
-- LIMPEZA FINAL: Remover cnpj_academia de todas tabelas de usuários
-- ============================================
-- Mantém cnpj_academia APENAS em users_adm
-- Remove de users_nutricionista, users_personal, users_alunos

-- 1. REMOVER cnpj_academia das tabelas de usuários
ALTER TABLE public.users_nutricionista DROP COLUMN IF EXISTS cnpj_academia;
ALTER TABLE public.users_personal DROP COLUMN IF EXISTS cnpj_academia;
ALTER TABLE public.users_alunos DROP COLUMN IF EXISTS cnpj_academia;

-- 2. DROPAR E RECRIAR create_user_v4 SEM cnpj_academia
DROP FUNCTION IF EXISTS public.create_user_v4(TEXT, TEXT, JSONB);

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
    payment_due_day INT;
    next_due_date DATE;
    created_by_admin_id UUID;
BEGIN
    -- Extrair dados do metadata
    user_role := p_metadata->>'role';
    user_name := p_metadata->>'name';
    user_phone := p_metadata->>'phone';
    user_academia := p_metadata->>'academia';
    user_id_academia := (p_metadata->>'id_academia')::UUID;
    payment_due_day := (p_metadata->>'paymentDueDay')::INT;
    created_by_admin_id := (p_metadata->>'created_by_admin_id')::UUID;

    -- VALIDAÇÃO: id_academia é OBRIGATÓRIO
    IF user_id_academia IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'id_academia é obrigatório'
        );
    END IF;

    -- 1. Criar usuário no Auth
    BEGIN
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            confirmation_token,
            recovery_token,
            email_change_token_new,
            email_change,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_sent_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            p_email,
            crypt(p_password, gen_salt('bf')),
            NOW(),
            '',
            '',
            '',
            '',
            jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
            p_metadata,
            NOW(),
            NOW(),
            NOW()
        )
        RETURNING id INTO new_user_id;
    EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Email já cadastrado no sistema'
        );
    END;

    -- 2. Criar registro na tabela pública (SEM cnpj_academia)
    IF user_role = 'nutritionist' THEN
        INSERT INTO public.users_nutricionista (
            id,
            nome,
            email,
            telefone,
            academia,
            id_academia,
            created_by_admin_id,
            email_verified,
            created_at,
            updated_at
        ) VALUES (
            new_user_id,
            user_name,
            p_email,
            user_phone,
            user_academia,
            user_id_academia,
            created_by_admin_id,
            TRUE,
            NOW(),
            NOW()
        );
        
    ELSIF user_role = 'trainer' THEN
        INSERT INTO public.users_personal (
            id,
            nome,
            email,
            telefone,
            academia,
            id_academia,
            created_by_admin_id,
            email_verified,
            created_at,
            updated_at
        ) VALUES (
            new_user_id,
            user_name,
            p_email,
            user_phone,
            user_academia,
            user_id_academia,
            created_by_admin_id,
            TRUE,
            NOW(),
            NOW()
        );
        
    ELSIF user_role = 'student' THEN
        -- Calcular próximo vencimento
        IF payment_due_day IS NOT NULL THEN
            next_due_date := make_date(
                EXTRACT(YEAR FROM CURRENT_DATE)::INT,
                EXTRACT(MONTH FROM CURRENT_DATE)::INT,
                payment_due_day
            );
            
            IF next_due_date < CURRENT_DATE THEN
                next_due_date := next_due_date + INTERVAL '1 month';
            END IF;
        END IF;
        
        INSERT INTO public.users_alunos (
            id,
            nome,
            email,
            telefone,
            academia,
            id_academia,
            created_by_admin_id,
            email_verified,
            payment_due_day,
            next_payment_due,
            created_at,
            updated_at
        ) VALUES (
            new_user_id,
            user_name,
            p_email,
            user_phone,
            user_academia,
            user_id_academia,
            created_by_admin_id,
            TRUE,
            payment_due_day,
            next_due_date,
            NOW(),
            NOW()
        );
    ELSE
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Tipo de usuário inválido: ' || user_role
        );
    END IF;

    -- 3. Retornar sucesso
    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Usuário criado com sucesso',
        'user_id', new_user_id
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', FALSE,
        'message', 'Erro ao criar usuário: ' || SQLERRM,
        'detail', SQLSTATE
    );
END;
$$;

-- 3. GARANTIR PERMISSÕES
GRANT EXECUTE ON FUNCTION public.create_user_v4(TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_user_v4(TEXT, TEXT, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_user_v4(TEXT, TEXT, JSONB) TO anon;

-- 4. RECARREGAR SCHEMA
NOTIFY pgrst, 'reload schema';

SELECT '✅ cnpj_academia removido de todas tabelas de usuários. Apenas users_adm mantém.' as status;
