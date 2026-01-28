-- SOLUÇÃO DE PERMISSÃO E RLS PARA CONFIRMAÇÃO DE CADASTRO
-- Rode este script no Supabase SQL Editor

-- 1. Garantir que a tabela users_adm permita inserção
-- Como a função RPC é SECURITY DEFINER, ela roda como superusuário,
-- mas RLS (Row Level Security) ainda pode bloquear se não houver política.

ALTER TABLE public.users_adm ENABLE ROW LEVEL SECURITY;

-- 2. Política para permitir que a função insira dados (bypass RLS)
-- Na verdade, SECURITY DEFINER já deve bypassar RLS se declarado corretamente,
-- mas vamos garantir que não haja bloqueio explícito.

-- Remover políticas antigas de INSERT para evitar conflito
DROP POLICY IF EXISTS "Permitir Insert RPC" ON public.users_adm;
DROP POLICY IF EXISTS "Insert Admin" ON public.users_adm;

-- Política permissiva para o Postgres (role de sistema que executa a RPC)
CREATE POLICY "System Insert Admin"
    ON public.users_adm
    FOR INSERT
    TO postgres, service_role, authenticated, anon
    WITH CHECK (true);

-- 3. Política para permitir UPDATE (caso o usuário já exista parcialmente)
CREATE POLICY "System Update Admin"
    ON public.users_adm
    FOR UPDATE
    TO postgres, service_role, authenticated, anon
    USING (true)
    WITH CHECK (true);

-- 4. Reafirmar permissões da função RPC
GRANT EXECUTE ON FUNCTION public.confirm_user_registration(text) TO anon, authenticated, service_role;

-- 5. Garantir Grants na tabela
GRANT ALL ON public.users_adm TO postgres, service_role;
GRANT INSERT, UPDATE, SELECT ON public.users_adm TO anon, authenticated;

-- 6. Recriar a função garantindo search_path e security definer (mesmo código da V2, só pra garantir que está no ar com as permissões novas)
CREATE OR REPLACE FUNCTION public.confirm_user_registration(token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER -- Roda com permissões de quem criou (postgres)
SET search_path = public, auth, extensions
AS $$
DECLARE
    parts text[];
    payload_b64 text;
    signature_b64 text;
    secret_key text := 'Sp4rt4n-App-2026-S3cr3tK3y-XyZ123-Secure';
    calc_sig bytea;
    calc_sig_b64 text;
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

    calc_sig := digest(payload_b64 || '.' || secret_key, 'sha256');
    calc_sig_b64 := encode(calc_sig, 'base64');
    calc_sig_b64 := replace(replace(calc_sig_b64, '+', '-'), '/', '_');
    calc_sig_b64 := rtrim(calc_sig_b64, '=');
    
    IF calc_sig_b64 != signature_b64 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Assinatura inválida.');
    END IF;

    payload_b64 := replace(replace(payload_b64, '-', '+'), '_', '/');
    BEGIN
        payload_json := convert_from(decode(payload_b64, 'base64'), 'UTF8')::jsonb;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'message', 'JSON Payload inválido.');
    END;

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
        
        -- AQUI É A PARTE CRÍTICA --
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
