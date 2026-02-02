-- FIX FINAL V4.2 - DEBUG EXTREMO
-- Vamos garantir que a extração do UUID funciona e, se falhar, GRITA antes do insert.

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
    v_id_academia_str TEXT; -- Pegar como texto primeiro
    v_id_academia UUID;
    v_academia_nome TEXT;
    v_cnpj_academia TEXT;
BEGIN
    -- DEBUG:
    RAISE LOG 'METADATA RECEBIDO: %', p_metadata;

    v_role := p_metadata->>'role';
    
    -- Tenta pegar id_academia como TEXTO primeiro
    v_id_academia_str := p_metadata->>'id_academia';
    
    -- Se vazio, fallback
    IF v_id_academia_str IS NULL OR v_id_academia_str = '' THEN
         v_id_academia_str := p_metadata->>'created_by_admin_id';
    END IF;

    -- Converte para UUID
    BEGIN
        v_id_academia := v_id_academia_str::UUID;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'message', 'ERRO UUID: id_academia inválido: ' || COALESCE(v_id_academia_str, 'NULL'));
    END;

    v_academia_nome := p_metadata->>'academia';
    v_cnpj_academia := p_metadata->>'cnpj_academia';

    -- VALIDAÇÃO FINAL ANTES DO INSERT
    IF v_id_academia IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'ERRO LÓGICO: id_academia é NULL após extração.');
    END IF;

    -- INSERT DO AUTH USER
    v_user_id := extensions.uuid_generate_v4();
    
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at
    ) VALUES (
        '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated', p_email, crypt(p_password, gen_salt('bf')), NOW(), p_metadata, NOW(), NOW()
    );

    -- INSERT NA TABELA PÚBLICA (Com id explícito)
    IF v_role = 'student' THEN
        INSERT INTO public.users_alunos (
            id, 
            id_academia, -- <--- AQUI
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
            v_id_academia,  -- <--- Valor Validado
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
         RETURN jsonb_build_object('success', false, 'message', 'Role não suportado: ' || v_role);
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Usuário criado com sucesso!', 'user_id', v_user_id);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'ERRO SQL GERAL: ' || SQLERRM);
END;
$$;
