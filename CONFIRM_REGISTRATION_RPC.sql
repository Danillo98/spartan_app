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
    current_user_id uuid;
    
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
    -- 1. Verificar autenticação
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Usuário não autenticado. Faça login primeiro.');
    END IF;

    -- 2. Parse do Token (Formato: payload.signature)
    parts := string_to_array(token, '.');
    IF array_length(parts, 1) != 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Formato de token inválido.');
    END IF;

    payload_b64 := parts[1];
    signature_b64 := parts[2];

    -- 3. Verificar Assinatura (HMAC SHA256)
    -- Recalcula: sha256( payload_b64 + '.' + secret_key )
    -- Nota: O Dart usa sha256.convert(utf8.encode('$base64Data.$_secretKey'))
    -- Portanto é um HASH simples da string concatenada, não um HMAC padrão.
    
    calc_sig := digest(payload_b64 || '.' || secret_key, 'sha256');
    calc_sig_b64 := encode(calc_sig, 'base64');
    
    -- Converter base64 padrão (Postgres) para UrlSafe (Dart)
    -- + para -, / para _, remover =
    calc_sig_b64 := replace(replace(calc_sig_b64, '+', '-'), '/', '_');
    calc_sig_b64 := rtrim(calc_sig_b64, '=');
    
    IF calc_sig_b64 != signature_b64 THEN
         RETURN jsonb_build_object('success', false, 'message', 'Assinatura do token inválida.');
    END IF;

    -- 4. Decodificar Payload
    -- Postgres precisa de base64 padrão (+ e /)
    payload_b64 := replace(replace(payload_b64, '-', '+'), '_', '/');
    
    -- Adicionar padding se necessário (simplesmente tentar decodificar)
    BEGIN
        payload_json := convert_from(decode(payload_b64, 'base64'), 'UTF8')::jsonb;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'message', 'Erro ao decodificar payload JSON.');
    END;

    -- 5. Extrair Dados
    v_name := payload_json->>'name';
    v_email := payload_json->>'email';
     -- password ignorado
    v_phone := payload_json->>'phone';
    v_cnpj := payload_json->>'cnpj'; -- ID/CNPJ Academia
    v_cpf := payload_json->>'cpf';   -- Nome Academia
    v_address := payload_json->>'address';
    
    -- 6. Inserir na Tabela Correta
    -- Parse do address para pegar o role: role|...
    v_address_parts := string_to_array(v_address, '|');
    v_role := v_address_parts[1]; 
    
    IF v_role = 'admin' THEN
         -- Inserir Admin
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
            current_user_id, 
            v_name, 
            v_email, 
            v_phone, 
            v_cnpj, 
            v_cpf, 
            CASE WHEN array_length(v_address_parts, 1) >= 3 THEN v_address_parts[3] ELSE '' END, -- CPF pessoal
            CASE WHEN array_length(v_address_parts, 1) >= 4 THEN v_address_parts[4] ELSE '' END, -- Endereço
            true
         )
         ON CONFLICT (id) DO UPDATE SET email_verified = true;
         
         RETURN jsonb_build_object('success', true, 'message', 'Administrador confirmado com sucesso!');
    ELSE
         -- Outros roles (apenas segurança)
         RETURN jsonb_build_object('success', false, 'message', 'Role não suportado por esta função.');
    END IF;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erro interno no banco: ' || SQLERRM);
END;
$$;
