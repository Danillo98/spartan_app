-- FIX FINAL V6 - REMOÇÃO CIRÚRGICA DA TRIGGER
-- Vamos remover a trigger automática que está causando o conflito, 
-- pois agora nossa RPC create_user_v4 cuida de tudo com segurança.

-- 1. Tentar remover triggers conhecidas que causam este problema
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_user_created ON auth.users; -- Nome alternativo comum

-- 2. Recriar a função V4 limpa (sem o session_replication_role)
DROP FUNCTION IF EXISTS create_user_v4(text, text, jsonb);

CREATE OR REPLACE FUNCTION create_user_v4(
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
    v_id_academia_str TEXT;
    v_id_academia UUID;
    v_academia_nome TEXT;
    v_cnpj_academia TEXT;
BEGIN
    v_role := p_metadata->>'role';
    v_id_academia_str := p_metadata->>'id_academia';
    
    IF v_id_academia_str IS NULL OR v_id_academia_str = '' THEN
         v_id_academia_str := p_metadata->>'created_by_admin_id';
    END IF;

    -- Cast seguro
    BEGIN
        v_id_academia := v_id_academia_str::UUID;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'message', 'ERRO UUID: id_academia inválido.');
    END;

    v_academia_nome := p_metadata->>'academia';
    v_cnpj_academia := p_metadata->>'cnpj_academia';

    IF v_id_academia IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'ERRO: ID Academia NULL.');
    END IF;

    v_user_id := extensions.uuid_generate_v4();
    
    -- 1. Insert Auth (Agora sem trigger para atrapalhar)
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at
    ) VALUES (
        '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated', p_email, crypt(p_password, gen_salt('bf')), NOW(), p_metadata, NOW(), NOW()
    );

    -- 2. Insert Público
    IF v_role = 'student' THEN
        INSERT INTO public.users_alunos (
            id, id_academia, created_by_admin_id, nome, email, telefone, academia, cnpj_academia, role, is_blocked, payment_due_day
        ) VALUES (
            v_user_id, v_id_academia, (p_metadata->>'created_by_admin_id')::UUID, p_metadata->>'name', p_email, p_metadata->>'phone', v_academia_nome, v_cnpj_academia, 'student', false, (p_metadata->>'paymentDueDay')::INTEGER
        );
    ELSIF v_role = 'trainer' THEN
         INSERT INTO public.users_personal (
            id, id_academia, created_by_admin_id, nome, email, telefone, academia, cnpj_academia, role, is_blocked
        ) VALUES (
            v_user_id, v_id_academia, (p_metadata->>'created_by_admin_id')::UUID, p_metadata->>'name', p_email, p_metadata->>'phone', v_academia_nome, v_cnpj_academia, 'trainer', false
        );
    ELSIF v_role = 'nutritionist' THEN
         INSERT INTO public.users_nutricionista (
            id, id_academia, created_by_admin_id, nome, email, telefone, academia, cnpj_academia, role, is_blocked
        ) VALUES (
            v_user_id, v_id_academia, (p_metadata->>'created_by_admin_id')::UUID, p_metadata->>'name', p_email, p_metadata->>'phone', v_academia_nome, v_cnpj_academia, 'nutritionist', false
        );
    ELSE
         RETURN jsonb_build_object('success', false, 'message', 'Role inválido.');
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Usuário criado com sucesso!', 'user_id', v_user_id);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'ERRO SQL (V6): ' || SQLERRM);
END;
$$;
