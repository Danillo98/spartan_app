-- ============================================================
-- CREATE_USER_V5 - VERSÃO DEFINITIVA COM auth.identities
-- ============================================================
-- Diferença da V4: Após criar auth.users, cria OBRIGATORIAMENTE
-- a entrada em auth.identities no formato exato que o GoTrue espera.
-- Sem auth.identities, o GoTrue retorna 500 "Database error querying schema"
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
    -- Captura básica de metadata
    user_role               := p_metadata->>'role';
    user_name               := p_metadata->>'name';
    user_phone              := p_metadata->>'phone';
    user_academia           := COALESCE(p_metadata->>'academia', 'Academia');
    user_id_academia        := (p_metadata->>'id_academia')::UUID;
    v_payment_due_day       := (p_metadata->>'paymentDueDay')::INT;
    v_birth_date            := (p_metadata->>'birthDate')::DATE;
    v_created_by_admin_id   := (p_metadata->>'created_by_admin_id')::UUID;
    v_is_paid_current_month := COALESCE((p_metadata->>'isPaidCurrentMonth')::BOOLEAN, FALSE);

    IF v_created_by_admin_id IS NULL THEN
        v_created_by_admin_id := user_id_academia;
    END IF;

    -- Gerar UUID único para o novo usuário
    new_user_id := gen_random_uuid();

    -- ============================================================
    -- PASSO 1: Criar usuário em auth.users
    -- CRÍTICO: Campos de token DEVEM ser '' (não NULL)!
    -- GoTrue em Go usa string (não *string), então NULL causa:
    -- "Scan error: converting NULL to string is unsupported"
    -- ============================================================
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_sent_at,
        is_sso_user,
        is_anonymous,
        confirmation_token,
        recovery_token,
        email_change_token_new,
        email_change_token_current,
        email_change,
        phone_change,
        phone_change_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        new_user_id,
        'authenticated',
        'authenticated',
        LOWER(p_email),
        crypt(p_password, gen_salt('bf', 10)),
        NOW(),
        jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
        p_metadata,
        NOW(),
        NOW(),
        NOW(),
        FALSE, -- is_sso_user
        FALSE, -- is_anonymous
        '',    -- confirmation_token: '' NÃO NULL
        '',    -- recovery_token: '' NÃO NULL
        '',    -- email_change_token_new
        '',    -- email_change_token_current
        '',    -- email_change
        '',    -- phone_change
        ''     -- phone_change_token
    );

    -- ============================================================
    -- PASSO 2: Criar identity em auth.identities (CRÍTICO!)
    -- Sem isso, GoTrue retorna "Database error querying schema"
    -- ============================================================
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        new_user_id,
        jsonb_build_object(
            'sub',            new_user_id::text,
            'email',          LOWER(p_email),
            'email_verified', true,
            'phone_verified', false
        ),
        'email',
        new_user_id::text,  -- provider_id = UUID (padrão GoTrue)
        NOW(),
        NOW(),
        NOW()
    );

    -- ============================================================
    -- PASSO 3: Inserir na tabela pública conforme o Role
    -- ============================================================
    IF user_role = 'student' THEN
        -- Calcular próxima data de vencimento
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

        INSERT INTO public.users_alunos (
            id, nome, email, telefone, academia, id_academia,
            created_by_admin_id, email_verified, payment_due_day,
            next_payment_due, data_nascimento, created_at, updated_at, is_paid_current_month
        ) VALUES (
            new_user_id, user_name, LOWER(p_email), user_phone, user_academia, user_id_academia,
            v_created_by_admin_id, TRUE, v_payment_due_day,
            v_next_due_date, v_birth_date, NOW(), NOW(), v_is_paid_current_month
        );

    ELSIF user_role = 'nutritionist' THEN
        INSERT INTO public.users_nutricionista (
            id, nome, email, telefone, academia, id_academia,
            created_by_admin_id, email_verified, created_at, updated_at
        ) VALUES (
            new_user_id, user_name, LOWER(p_email), user_phone, user_academia, user_id_academia,
            v_created_by_admin_id, TRUE, NOW(), NOW()
        );

    ELSIF user_role = 'trainer' THEN
        INSERT INTO public.users_personal (
            id, nome, email, telefone, academia, id_academia,
            created_by_admin_id, email_verified, created_at, updated_at
        ) VALUES (
            new_user_id, user_name, LOWER(p_email), user_phone, user_academia, user_id_academia,
            v_created_by_admin_id, TRUE, NOW(), NOW()
        );
    END IF;

    -- Notifica PostgREST e retorna sucesso
    NOTIFY pgrst, 'reload schema';
    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Usuário criado com sucesso',
        'user_id', new_user_id
    );

EXCEPTION WHEN OTHERS THEN
    -- Rollback completo: remove auth user e identity se algo falhar
    DELETE FROM auth.identities WHERE user_id = new_user_id;
    DELETE FROM auth.users WHERE id = new_user_id;
    RETURN jsonb_build_object(
        'success', FALSE,
        'message', 'Erro Fatal ao Cadastrar: ' || SQLERRM || ' | Code: ' || SQLSTATE
    );
END;
$$;

-- ============================================================
-- REPARAR TODOS OS USUÁRIOS EXISTENTES SEM IDENTITY
-- ============================================================
-- Deleta identities em formato errado (provider_id = email)
DELETE FROM auth.identities
WHERE provider = 'email'
AND provider_id NOT SIMILAR TO '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';

-- Cria identities corretos para todos os usuários sem identity
INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
)
SELECT
    gen_random_uuid(),
    u.id,
    jsonb_build_object(
        'sub',            u.id::text,
        'email',          u.email,
        'email_verified', true,
        'phone_verified', false
    ),
    'email',
    u.id::text,
    NOW(), NOW(), NOW()
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM auth.identities i WHERE i.user_id = u.id
)
AND u.email IS NOT NULL;

-- Garantir is_sso_user e is_anonymous corretos para usuários existentes
UPDATE auth.users
SET 
    is_sso_user = FALSE,
    is_anonymous = FALSE
WHERE is_sso_user IS NULL OR is_anonymous IS NULL;

NOTIFY pgrst, 'reload schema';

-- Verificar resultado
SELECT 
    u.email,
    u.is_sso_user,
    u.is_anonymous,
    (SELECT COUNT(*) FROM auth.identities i WHERE i.user_id = u.id) as identities
FROM auth.users u
WHERE u.email IN ('da@gmail.com', 'teste123@gmail.com')
ORDER BY u.email;

SELECT '✅ create_user_v4 atualizado e todos os usuários reparados!' as status;
