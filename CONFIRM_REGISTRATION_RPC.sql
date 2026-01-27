-- Função RPC para completar o cadastro do administrador via Token Criptografado
-- Esta função deve ser chamada pela página web (confirm.html) após o login (exchangeCodeForSession)

-- 1. Garantir extensão pgcrypto
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;

-- 2. Função de Confirmação
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
    secret_key text := 'Sp4rt4n-App-2026-S3cr3tK3y-XyZ123-Secure'; -- MESMA CHAVE DO FLUTTER!
    calc_sig bytea;
    calc_sig_b64 text;
    payload_json jsonb;
    v_user_id uuid;
    
    -- Variáveis de dados
    v_name text;
    v_email text;
    v_phone text;
    v_cnpj text;
    v_cpf text;
    v_address text;
    v_role text;
    
    v_address_parts text[];
BEGIN
    -- 1. Parse do Token (Formato: payload.signature)
    parts := string_to_array(token, '.');
    IF array_length(parts, 1) != 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Formato de token inválido.');
    END IF;

    payload_b64 := parts[1];
    signature_b64 := parts[2];

    -- 2. Verificar Assinatura (HMAC SHA256)
    -- Recalcula: sha256( payload_b64 + '.' + secret_key )
    calc_sig := digest(payload_b64 || '.' || secret_key, 'sha256');
    calc_sig_b64 := encode(calc_sig, 'base64');
    
    -- Converter base64 padrão (Postgres) para UrlSafe (Dart)
    calc_sig_b64 := replace(replace(calc_sig_b64, '+', '-'), '/', '_');
    calc_sig_b64 := rtrim(calc_sig_b64, '=');
    
    IF calc_sig_b64 != signature_b64 THEN
         RETURN jsonb_build_object('success', false, 'message', 'Assinatura do token inválida.');
    END IF;

    -- 3. Decodificar Payload
    payload_b64 := replace(replace(payload_b64, '-', '+'), '_', '/');
    
    BEGIN
        payload_json := convert_from(decode(payload_b64, 'base64'), 'UTF8')::jsonb;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'message', 'Erro ao decodificar payload JSON.');
    END;

    -- 4. Extrair e Validar Usuário
    v_email := payload_json->>'email';
    
    -- Buscar ID do usuário no Auth (sem depender da sessão atual)
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
    
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Usuário não encontrado. Cadastre-se novamente.');
    END IF;

    -- 5. Extrair Restante dos Dados
    v_name := payload_json->>'name';
    v_phone := payload_json->>'phone';
    v_cnpj := payload_json->>'cnpj'; -- ID/CNPJ Academia
    v_cpf := payload_json->>'cpf';   -- Nome Academia
    v_address := payload_json->>'address';
    
    -- 6. Confirmar Email Manualmente (Bypass PKCE Confirm)
    UPDATE auth.users 
    SET email_confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = v_user_id;

    -- 7. Inserir na Tabela Correta
    v_address_parts := string_to_array(v_address, '|');
    v_role := v_address_parts[1]; 
    
    IF v_role = 'admin' THEN
         INSERT INTO public.users_adm (
            id, 
            nome, 
            email, 
            telefone, 
            cnpj_academia, 
            academia, 
            cpf, 
            endereco, 
            email_verified
         )
         VALUES (
            v_user_id, 
            v_name, 
            v_email, 
            v_phone, 
            v_cnpj, 
            v_cpf, 
            CASE WHEN array_length(v_address_parts, 1) >= 3 THEN v_address_parts[3] ELSE '' END, 
            CASE WHEN array_length(v_address_parts, 1) >= 4 THEN v_address_parts[4] ELSE '' END, 
            true
         )
         ON CONFLICT (id) DO UPDATE SET email_verified = true;
         
         RETURN jsonb_build_object('success', true, 'message', 'Administrador confirmado com sucesso!');
    ELSE
         RETURN jsonb_build_object('success', false, 'message', 'Role não suportado por esta função.');
    END IF;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erro interno no banco: ' || SQLERRM);
END;
$$;

-- 3. Permitir que Anon e Authenticated executem a função
GRANT EXECUTE ON FUNCTION public.confirm_user_registration(text) TO anon, authenticated, service_role;
