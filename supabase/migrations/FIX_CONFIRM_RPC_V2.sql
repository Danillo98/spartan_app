-- RPC Reimplantada com Logs Melhores e Lógica Defensiva
-- Rodar no Supabase SQL Editor

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
    secret_key text := 'Sp4rt4n-App-2026-S3cr3tK3y-XyZ123-Secure'; -- Verificar se bate com o Flutter
    calc_sig bytea;
    calc_sig_b64 text;
    payload_json jsonb;
    v_user_id uuid;
    
    -- Campos
    v_email text;
    v_name text;
    v_phone text;
    v_cnpj text;
    v_academy_field text; 
    v_address_full text;
    
    -- Parsing
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

    payload_b64 := parts[1];
    signature_b64 := parts[2];

    -- 2. Validar Assinatura (Opcional - Se falhar, comentar este bloco para debug)
    calc_sig := digest(payload_b64 || '.' || secret_key, 'sha256');
    calc_sig_b64 := encode(calc_sig, 'base64');
    calc_sig_b64 := replace(replace(calc_sig_b64, '+', '-'), '/', '_');
    calc_sig_b64 := rtrim(calc_sig_b64, '=');
    
    IF calc_sig_b64 != signature_b64 THEN
        -- Retornar erro mas LOGAR o que aconteceu
        RAISE WARNING 'Assinatura inválida. Calc: %, Rec: %', calc_sig_b64, signature_b64;
        RETURN jsonb_build_object('success', false, 'message', 'Assinatura inválida.');
    END IF;

    -- 3. Decode Payload
    payload_b64 := replace(replace(payload_b64, '-', '+'), '_', '/');
    BEGIN
        payload_json := convert_from(decode(payload_b64, 'base64'), 'UTF8')::jsonb;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'message', 'JSON Payload inválido.');
    END;

    -- 4. Auth User Check
    v_email := payload_json->>'email';
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
    
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Usuário não encontrado no Auth para email: ' || v_email);
    END IF;

    -- 5. Extração de Dados
    v_name := payload_json->>'name';
    v_phone := payload_json->>'phone';
    v_cnpj := payload_json->>'cnpj';
    v_academy_field := payload_json->>'cpf'; -- No App Flutter, o campo 'cpf' do JSON parece estar levando o Nome da Academia
    v_address_full := payload_json->>'address';
    
    -- 6. Logica de Parse "Pipe" do Flutter
    -- Formato esperado: "admin|NOME_ACADEMIA_OU_ID|CPF_PESSOA|ENDERECO"
    v_address_parts := string_to_array(v_address_full, '|');
    
    IF array_length(v_address_parts, 1) >= 1 THEN
        v_role := v_address_parts[1];
    ELSE
        v_role := 'admin'; -- Default seguro
    END IF;

    -- Parse CPF e Endereço
    IF array_length(v_address_parts, 1) >= 3 THEN
        v_real_cpf := v_address_parts[3];
    ELSE
        v_real_cpf := ''; 
    END IF;

    IF array_length(v_address_parts, 1) >= 4 THEN
        v_real_address := v_address_parts[4];
    ELSE
        v_real_address := v_address_full; -- Usa tudo se não tiver pipes
    END IF;

    -- 7. Inserção
    IF v_role = 'admin' THEN
        -- Confirmar Email
        UPDATE auth.users SET email_confirmed_at = now() WHERE id = v_user_id;
        
        -- Upsert Users Adm
        INSERT INTO public.users_adm (
            id, nome, email, telefone, 
            cnpj_academia, academia, cpf, endereco, 
            email_verified
        ) VALUES (
            v_user_id,
            v_name,
            v_email,
            v_phone,
            v_cnpj,
            v_academy_field, -- Usando o campo 'cpf' do JSON como Nome da Academia
            v_real_cpf,      -- Usando o CPF extraído do pipe
            v_real_address,
            true
        )
        ON CONFLICT (id) DO UPDATE SET
            email_verified = true,
            telefone = EXCLUDED.telefone; -- Atualiza algo para garantir
            
        RETURN jsonb_build_object('success', true, 'message', 'Conta ativada com sucesso!');
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Role inválido: ' || v_role);
    END IF;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erro Interno SQL: ' || SQLERRM);
END;
$$;
