-- FIX FINAL: CREATE USER V4.1
-- Apaga versões anteriores da v4 para evitar cache/conflito e recria.

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
    v_id_academia UUID;
    v_academia_nome TEXT;
    v_cnpj_academia TEXT;
BEGIN
    -- LOG PARA DEBUG (Aparece nos logs do Supabase em Database > Postgres Logs)
    RAISE LOG 'Iniciando create_user_v4. Metadata: %', p_metadata;

    v_role := p_metadata->>'role';
    
    -- Tenta pegar id_academia de TODAS as formas possíveis
    v_id_academia := (p_metadata->>'id_academia')::UUID;
    
    IF v_id_academia IS NULL THEN
        -- Tenta pegar do created_by se o principal falhar
        v_id_academia := (p_metadata->>'created_by_admin_id')::UUID; 
    END IF;

    v_academia_nome := p_metadata->>'academia';
    v_cnpj_academia := p_metadata->>'cnpj_academia';

    -- Validação: Se continuar NULL, aborta com mensagem clara
    IF v_id_academia IS NULL THEN
        RAISE EXCEPTION 'ERRO_CUSTOMIZADO: O campo id_academia está NULO no Metadata recebido.';
    END IF;

    -- Executa Insert
    v_user_id := extensions.uuid_generate_v4();
    
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at
    ) VALUES (
        '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated', p_email, crypt(p_password, gen_salt('bf')), NOW(), p_metadata, NOW(), NOW()
    );

    IF v_role = 'student' THEN
        INSERT INTO public.users_alunos (
            id, id_academia, created_by_admin_id, nome, email, telefone, academia, cnpj_academia, role, is_blocked, payment_due_day
        ) VALUES (
            v_user_id, 
            v_id_academia, -- AQUI ESTÁ A CHAVE
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
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Role não suportado ainda neste fix.');
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Usuário criado com sucesso!', 'user_id', v_user_id);

EXCEPTION WHEN OTHERS THEN
    -- Captura o erro exato e devolve
    RETURN jsonb_build_object('success', false, 'message', 'ERRO SQL: ' || SQLERRM);
END;
$$;
