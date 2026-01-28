-- SOLUÇÃO DEFINITIVA DE SEGURANÇA NA RPC
-- Assinatura validada via BYTES para evitar erros de formatação Base64
-- Rode este script no Supabase SQL Editor

CREATE OR REPLACE FUNCTION public.confirm_user_registration(token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    parts text[];
    payload_raw text;
    signature_raw text;
    secret_key text := 'Sp4rt4n-App-2026-S3cr3tK3y-XyZ123-Secure';
    
    -- Cálculos
    calc_sig_bytes bytea;
    received_sig_bytes bytea;
    signature_std text;
    pad_len int;
    
    payload_json jsonb;
    v_user_id uuid;
    
    -- Dados do Usuário
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
    -- 1. Parse Token
    parts := string_to_array(token, '.');
    IF array_length(parts, 1) != 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Formato de token inválido.');
    END IF;

    payload_raw := parts[1];
    signature_raw := parts[2];

    -- 2. Validar Assinatura (Robustez: Comparação em Bytes)
    
    -- A. Calcular o hash localmente
    calc_sig_bytes := digest(payload_raw || '.' || secret_key, 'sha256');
    
    -- B. Converter assinatura recebida (UrlSafe) para Standard Base64 e depois para Bytes
    signature_std := replace(replace(signature_raw, '-', '+'), '_', '/');
    
    -- Adicionar Padding se necessário
    pad_len := 4 - (length(signature_std) % 4);
    IF pad_len < 4 THEN
        signature_std := signature_std || repeat('=', pad_len);
    END IF;
    
    BEGIN
        received_sig_bytes := decode(signature_std, 'base64');
    EXCEPTION WHEN OTHERS THEN
         RETURN jsonb_build_object('success', false, 'message', 'Assinatura malformada.');
    END;

    -- C. Comparação Binária
    IF calc_sig_bytes != received_sig_bytes THEN
        -- Se falhar, retornar detalhes técnicos para debug se necessário
        -- RETURN jsonb_build_object('success', false, 'message', 'Assinatura não confere.');
        RETURN jsonb_build_object('success', false, 'message', 'Assinatura inválida (Hash Mismatch).');
    END IF;

    -- 3. Decode Payload
    -- Converter Payload UrlSafe -> Standard -> JSON
    payload_raw := replace(replace(payload_raw, '-', '+'), '_', '/');
    pad_len := 4 - (length(payload_raw) % 4);
    IF pad_len < 4 THEN
        payload_raw := payload_raw || repeat('=', pad_len);
    END IF;

    BEGIN
        payload_json := convert_from(decode(payload_raw, 'base64'), 'UTF8')::jsonb;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'message', 'JSON Payload inválido.');
    END;

    -- 4. Verificar Expiração
    IF (payload_json->>'exp') IS NOT NULL THEN
        IF (to_timestamp((payload_json->>'exp')::bigint / 1000) < now()) THEN
             RETURN jsonb_build_object('success', false, 'message', 'Link expirado.');
        END IF;
    END IF;

    -- 5. Lógica de Cadastro (Idêntica à anterior)
    v_email := payload_json->>'email';
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
    
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Usuário não encontrado no Auth.');
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
        UPDATE auth.users SET email_confirmed_at = now() WHERE id = v_user_id;
        
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
            
        RETURN jsonb_build_object('success', true, 'message', 'Conta ativada com sucesso!');
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Role inválido: ' || v_role);
    END IF;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erro SQL: ' || SQLERRM);
END;
$$;
