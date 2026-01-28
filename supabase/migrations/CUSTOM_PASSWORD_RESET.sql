-- SISTEMA CUSTOMIZADO DE RESET DE SENHA
-- Cria uma tabela para armazenar tokens temporários e uma função para validar

-- 1. Tabela para tokens de reset
CREATE TABLE IF NOT EXISTS public.password_reset_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token text NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    used boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_reset_tokens_token ON public.password_reset_tokens(token);
CREATE INDEX IF NOT EXISTS idx_reset_tokens_user ON public.password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_reset_tokens_expires ON public.password_reset_tokens(expires_at);

-- RLS
ALTER TABLE public.password_reset_tokens ENABLE ROW LEVEL SECURITY;

-- Política: Apenas o sistema pode ler/escrever
DROP POLICY IF EXISTS "System only access" ON public.password_reset_tokens;
CREATE POLICY "System only access" ON public.password_reset_tokens
    FOR ALL USING (false);

-- 2. Função para gerar token (APP envia o email)
CREATE OR REPLACE FUNCTION public.request_password_reset(user_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_token text;
    v_expires_at timestamptz;
    v_reset_url text;
BEGIN
    -- Buscar usuário
    SELECT id INTO v_user_id 
    FROM auth.users 
    WHERE email = user_email;
    
    IF v_user_id IS NULL THEN
        -- Por segurança, não revelar se o email existe ou não
        RETURN jsonb_build_object('success', true, 'message', 'Se o email existir, você receberá um link.');
    END IF;
    
    -- Gerar token seguro (32 caracteres aleatórios)
    v_token := encode(gen_random_bytes(24), 'base64');
    v_token := replace(replace(replace(v_token, '+', '-'), '/', '_'), '=', '');
    
    -- Expiração: 1 hora
    v_expires_at := now() + interval '1 hour';
    
    -- Salvar token
    INSERT INTO public.password_reset_tokens (user_id, token, expires_at)
    VALUES (v_user_id, v_token, v_expires_at);
    
    -- Construir URL
    v_reset_url := 'https://spartanapp.com.br/reset-password.html?token=' || v_token;
    
    -- Retornar URL para o app enviar o email
    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Token gerado com sucesso!',
        'reset_url', v_reset_url,
        'email', user_email
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erro ao processar: ' || SQLERRM);
END;
$$;

-- 3. Função para validar token e resetar senha
CREATE OR REPLACE FUNCTION public.reset_password_with_token(
    reset_token text,
    new_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_token_record record;
BEGIN
    -- Buscar token
    SELECT * INTO v_token_record
    FROM public.password_reset_tokens
    WHERE token = reset_token
    AND used = false
    AND expires_at > now();
    
    IF v_token_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Token inválido ou expirado.');
    END IF;
    
    v_user_id := v_token_record.user_id;
    
    -- Atualizar senha no auth.users
    UPDATE auth.users
    SET encrypted_password = crypt(new_password, gen_salt('bf'))
    WHERE id = v_user_id;
    
    -- Marcar token como usado
    UPDATE public.password_reset_tokens
    SET used = true
    WHERE id = v_token_record.id;
    
    -- Limpar tokens antigos do usuário
    DELETE FROM public.password_reset_tokens
    WHERE user_id = v_user_id
    AND id != v_token_record.id;
    
    RETURN jsonb_build_object('success', true, 'message', 'Senha alterada com sucesso!');
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erro ao resetar senha: ' || SQLERRM);
END;
$$;

-- Grants
GRANT EXECUTE ON FUNCTION public.request_password_reset(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reset_password_with_token(text, text) TO anon, authenticated;

-- Limpeza automática de tokens expirados (opcional - rodar periodicamente)
CREATE OR REPLACE FUNCTION public.cleanup_expired_reset_tokens()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.password_reset_tokens
    WHERE expires_at < now() - interval '24 hours';
END;
$$;
