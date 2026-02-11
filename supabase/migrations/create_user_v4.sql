-- ============================================
-- FUNÇÃO: Criar Usuário via Admin (RPC V4)
-- ============================================
-- Esta função cria usuários (Nutricionista, Personal, Aluno) via Admin
-- sem enviar email de verificação e com acesso imediato

CREATE OR REPLACE FUNCTION create_user_v4(
    p_email TEXT,
    p_password TEXT,
    p_metadata JSONB
)
RETURNS JSONB AS $$
DECLARE
    new_user_id UUID;
    user_role TEXT;
    user_name TEXT;
    user_phone TEXT;
    user_academia TEXT;
    user_id_academia UUID;
    user_cnpj TEXT;
    payment_due_day INT;
    is_paid_current_month BOOLEAN;
BEGIN
    -- Extrair dados do metadata
    user_role := p_metadata->>'role';
    user_name := p_metadata->>'name';
    user_phone := p_metadata->>'phone';
    user_academia := p_metadata->>'academia';
    user_id_academia := (p_metadata->>'id_academia')::UUID;
    user_cnpj := p_metadata->>'cnpj_academia';
    payment_due_day := (p_metadata->>'paymentDueDay')::INT;
    is_paid_current_month := COALESCE((p_metadata->>'isPaidCurrentMonth')::BOOLEAN, FALSE);

    -- 1. Criar usuário no Auth (Email já confirmado)
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
            NOW(), -- Email já confirmado
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

    -- 2. Criar registro na tabela pública apropriada
    IF user_role = 'nutritionist' THEN
        INSERT INTO public.users_nutricionista (
            id,
            nome,
            email,
            telefone,
            academia,
            cnpj_academia,
            id_academia,
            email_verified,
            created_at,
            updated_at
        ) VALUES (
            new_user_id,
            user_name,
            p_email,
            user_phone,
            user_academia,
            user_cnpj,
            user_id_academia,
            TRUE, -- Já verificado
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
            cnpj_academia,
            id_academia,
            email_verified,
            created_at,
            updated_at
        ) VALUES (
            new_user_id,
            user_name,
            p_email,
            user_phone,
            user_academia,
            user_cnpj,
            user_id_academia,
            TRUE,
            NOW(),
            NOW()
        );
        
    ELSIF user_role = 'student' THEN
        -- Calcular próximo vencimento
        DECLARE
            next_due_date DATE;
        BEGIN
            IF payment_due_day IS NOT NULL THEN
                next_due_date := make_date(
                    EXTRACT(YEAR FROM CURRENT_DATE)::INT,
                    EXTRACT(MONTH FROM CURRENT_DATE)::INT,
                    payment_due_day
                );
                
                -- Se a data já passou este mês, usar próximo mês
                IF next_due_date < CURRENT_DATE THEN
                    next_due_date := next_due_date + INTERVAL '1 month';
                END IF;
            END IF;
        END;
        
        INSERT INTO public.users_alunos (
            id,
            nome,
            email,
            telefone,
            academia,
            cnpj_academia,
            id_academia,
            email_verified,
            payment_due_day,
            is_paid_current_month,
            next_payment_due,
            created_at,
            updated_at
        ) VALUES (
            new_user_id,
            user_name,
            p_email,
            user_phone,
            user_academia,
            user_cnpj,
            user_id_academia,
            TRUE,
            payment_due_day,
            is_paid_current_month,
            next_due_date,
            NOW(),
            NOW()
        );
    ELSE
        -- Tipo de usuário desconhecido
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
    -- Em caso de erro, retornar detalhes
    RETURN jsonb_build_object(
        'success', FALSE,
        'message', 'Erro ao criar usuário: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Permissões
GRANT EXECUTE ON FUNCTION create_user_v4(TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION create_user_v4(TEXT, TEXT, JSONB) TO service_role;
