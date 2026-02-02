-- ATUALIZAÇÃO CRÍTICA DA RPC DE CADASTRO (create_user_v3)
-- Objetivo: Garantir que o campo 'id_academia' seja inserido corretamente nas tabelas de usuários.

CREATE OR REPLACE FUNCTION create_user_v3(
    p_email TEXT,
    p_password TEXT,
    p_metadata JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_role TEXT;
    v_table_name TEXT;
    v_id_academia UUID;
    v_academia_nome TEXT;
    v_cnpj_academia TEXT;
BEGIN
    -- 1. Extrair e Validar Dados Essenciais do Metadata
    v_role := p_metadata->>'role';
    
    -- Tenta pegar id_academia de várias formas possíveis para robustez
    v_id_academia := (p_metadata->>'id_academia')::UUID;
    IF v_id_academia IS NULL THEN
        v_id_academia := (p_metadata->>'created_by_admin_id')::UUID; -- Fallback
    END IF;

    v_academia_nome := p_metadata->>'academia';
    v_cnpj_academia := p_metadata->>'cnpj_academia';

    -- Validação Severa
    IF v_id_academia IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Erro Interno: ID da Academia não fornecido.');
    END IF;

    -- 2. Criar Usuário no Auth do Supabase
    -- Nota: O raw_user_meta_data armazenará tudo para uso futuro
    v_user_id := extensions.uuid_generate_v4();
    
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        v_user_id,
        'authenticated',
        'authenticated',
        p_email,
        crypt(p_password, gen_salt('bf')),
        NOW(), -- Email já confirmado
        p_metadata, -- Salva todo o metadata JSON
        NOW(),
        NOW(),
        '',
        ''
    );

    -- 3. Inserir na Tabela Pública Específica (Bypass Triggers problemáticas se houver)
    -- A lógica aqui substitui a necessidade de triggers complexas de insert
    
    IF v_role = 'student' THEN
        INSERT INTO public.users_alunos (
            id, 
            id_academia, 
            created_by_admin_id, 
            nome, 
            email, 
            telefone, 
            academia, 
            cnpj_academia,
            role, 
            is_blocked,
            payment_due_day
        ) VALUES (
            v_user_id,
            v_id_academia,
            (p_metadata->>'created_by_admin_id')::UUID,
            p_metadata->>'name',
            p_email,
            p_metadata->>'phone',
            v_academia_nome,
            v_cnpj_academia,
            'student',
            false,
            (p_metadata->>'paymentDueDay')::INTEGER
        );
        
    ELSIF v_role = 'trainer' THEN
        INSERT INTO public.users_personal (
            id, 
            id_academia, 
            created_by_admin_id, 
            nome, 
            email, 
            telefone, 
            academia, 
            cnpj_academia,
            role, 
            is_blocked
        ) VALUES (
            v_user_id,
            v_id_academia,
            (p_metadata->>'created_by_admin_id')::UUID,
            p_metadata->>'name',
            p_email,
            p_metadata->>'phone',
            v_academia_nome,
            v_cnpj_academia,
            'trainer',
            false
        );

    ELSIF v_role = 'nutritionist' THEN
        INSERT INTO public.users_nutricionista (
            id, 
            id_academia, 
            created_by_admin_id, 
            nome, 
            email, 
            telefone, 
            academia, 
            cnpj_academia,
            role, 
            is_blocked
        ) VALUES (
            v_user_id,
            v_id_academia,
            (p_metadata->>'created_by_admin_id')::UUID,
            p_metadata->>'name',
            p_email,
            p_metadata->>'phone',
            v_academia_nome,
            v_cnpj_academia,
            'nutritionist',
            false
        );
    
    ELSE
        -- Se não for nenhum role conhecido, retorna erro (exceto admin, que usa outro fluxo)
        RETURN jsonb_build_object('success', false, 'message', 'Role inválido para cadastro via RPC.');
    END IF;

    -- 4. Sucesso
    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Usuário criado com sucesso.', 
        'user_id', v_user_id
    );

EXCEPTION WHEN OTHERS THEN
    -- Em caso de erro (ex: Limite atingido vindo da Trigger), captura e retorna
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;
