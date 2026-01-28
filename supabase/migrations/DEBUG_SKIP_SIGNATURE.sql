-- DEBUG: Pular validação de assinatura para isolar erro de hash
-- Rode este script no Supabase SQL Editor

CREATE OR REPLACE FUNCTION public.confirm_user_registration(token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    parts text[];
    payload_b64 text;
    signature_b64 text;
    payload_json jsonb;
    v_user_id uuid;
    
    v_email text;
    v_name text;
    v_phone text;
    v_cnpj text;
    v_academy_field text; 
    v_address_full text;
    
    v_address_parts text[];
    v_role text;
    v_real_cpf text;
    v_real_address text;
BEGIN
    parts := string_to_array(token, '.');
    IF array_length(parts, 1) != 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Formato de token inválido.');
    END IF;

    payload_b64 := parts[1];
    signature_b64 := parts[2];

    -- DEBUG: Validação de assinatura pulada de propósito
    -- calc_sig := digest(payload_b64 || '.' || secret_key, 'sha256');
    -- IF calc_sig_b64 != signature_b64 THEN ...

    payload_b64 := replace(replace(payload_b64, '-', '+'), '_', '/');
    BEGIN
        payload_json := convert_from(decode(payload_b64, 'base64'), 'UTF8')::jsonb;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'message', 'JSON Payload inválido.');
    END;

    v_email := payload_json->>'email';
    -- IMPORTANTE: Log para saber quem estamos procurando
    -- RAISE NOTICE 'Procurando email: %', v_email;

    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
    
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Usuário não encontrado no Auth para: ' || v_email);
    END IF;

    v_name := payload_json->>'name';
    v_phone := payload_json->>'phone';
    v_cnpj := payload_json->>'cnpj';
    v_academy_field := payload_json->>'cpf'; 
    v_address_full := payload_json->>'address';
    
    v_address_parts := string_to_array(v_address_full, '|');
    v_role := COALESCE(v_address_parts[1], 'admin');

    IF array_length(v_address_parts, 1) >= 3 THEN v_real_cpf := v_address_parts[3]; ELSE v_real_cpf := ''; END IF;
    IF array_length(v_address_parts, 1) >= 4 THEN v_real_address := v_address_parts[4]; ELSE v_real_address := v_address_full; END IF;

    IF v_role = 'admin' THEN
        -- Marca email como confirmado
        UPDATE auth.users SET email_confirmed_at = now() WHERE id = v_user_id;
        
        -- Insere na tabela de admin
        INSERT INTO public.users_adm (
            id, nome, email, telefone, 
            cnpj_academia, academia, cpf, endereco, 
            email_verified
        ) VALUES (
            v_user_id, v_name, v_email, v_phone, 
            v_cnpj, v_academy_field, v_real_cpf, v_real_address, true
        )
        ON CONFLICT (id) DO UPDATE SET
            email_verified = true,
            telefone = EXCLUDED.telefone;
            
        RETURN jsonb_build_object('success', true, 'message', 'Conta ativada com sucesso (Debug Mode)!');
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Role inválido: ' || v_role);
    END IF;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erro SQL: ' || SQLERRM);
END;
$$;
