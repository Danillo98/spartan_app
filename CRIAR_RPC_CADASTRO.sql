-- CRIAR_RPC_CADASTRO.sql
-- Função RPC para criar usuários sem enviar e-mail de confirmação (Bypass do GoTrue via Banco)

-- Garantir que a extensão de criptografia esteja ativa
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.create_user_v3(
    p_email TEXT,
    p_password TEXT,
    p_metadata JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id UUID;
    v_encrypted_pw TEXT;
    v_instance_id UUID;
BEGIN
    -- Tenta pegar o instance_id padrão (geralmente 0000...)
    SELECT id INTO v_instance_id FROM auth.instances LIMIT 1;
    IF v_instance_id IS NULL THEN
        v_instance_id := '00000000-0000-0000-0000-000000000000'::UUID;
    END IF;

    -- Verificar duplicidade
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Este email já está cadastrado no sistema.');
    END IF;

    -- Gerar Hash da Senha
    v_encrypted_pw := crypt(p_password, gen_salt('bf'));
    v_user_id := gen_random_uuid();

    -- Inserir Novo Usuário em auth.users
    -- Isso cria o usuário JÁ CONFIRMADO e SEM disparar o e-mail do Auth Service
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        recovery_sent_at,
        last_sign_in_at,
        raw_app_meta_data,
        raw_user_meta_data,
        is_super_admin,
        created_at,
        updated_at,
        confirmation_token,
        email_change,
        email_change_token_new,
        recovery_token
    ) VALUES (
        v_instance_id,
        v_user_id,
        'authenticated',
        'authenticated',
        p_email,
        v_encrypted_pw,
        NOW(), -- CONFIRMADO IMEDIATAMENTE!
        NULL,
        NULL,
        '{"provider": "email", "providers": ["email"]}',
        p_metadata,
        false,
        NOW(),
        NOW(),
        '',
        '',
        '',
        ''
    );

    -- Nota: A trigger 'handle_new_user' (com suporte a id_academia) 
    -- irá rodar automaticamente após este INSERT, populando as tabelas 
    -- users_alunos, users_nutricionista, etc.

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Usuário criado com sucesso e ativo.',
        'user_id', v_user_id
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erro interno ao criar usuário: ' || SQLERRM);
END;
$$;
