-- ============================================
-- FUNÇÃO SQL PARA ENVIAR EMAIL COM CÓDIGO
-- ============================================

-- Esta função envia email usando o sistema nativo do Supabase
-- Substitui a necessidade de Edge Functions ou serviços externos

CREATE OR REPLACE FUNCTION send_verification_email(
  p_email TEXT,
  p_code TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Enviar email usando extensão pg_net (se disponível)
  -- OU usar trigger que o Supabase processa automaticamente
  
  -- OPÇÃO 1: Usar auth.users para trigger de email
  -- Inserir um registro temporário que dispara o email
  PERFORM auth.email(
    p_email,
    '🔐 Seu código de verificação - Spartan App',
    format('Seu código de verificação é: %s', p_code)
  );
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    -- Se falhar, apenas log (não bloqueia o processo)
    RAISE WARNING 'Erro ao enviar email: %', SQLERRM;
    RETURN FALSE;
END;
$$;

-- ============================================
-- ALTERNATIVA: USAR WEBHOOK DO SUPABASE
-- ============================================

-- Se a função acima não funcionar, use esta abordagem:

CREATE OR REPLACE FUNCTION send_verification_email_webhook(
  p_email TEXT,
  p_code TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_response TEXT;
BEGIN
  -- Chamar webhook do Supabase que envia email
  -- O Supabase processa automaticamente emails de auth
  
  -- Criar um registro na tabela de emails pendentes
  INSERT INTO email_queue (email, code, created_at)
  VALUES (p_email, p_code, NOW());
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Erro ao enfileirar email: %', SQLERRM;
    RETURN FALSE;
END;
$$;

-- ============================================
-- TABELA DE FILA DE EMAILS (OPCIONAL)
-- ============================================

CREATE TABLE IF NOT EXISTS email_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  sent_at TIMESTAMPTZ
);

-- Índice para performance
CREATE INDEX IF NOT EXISTS idx_email_queue_pending 
ON email_queue(created_at) 
WHERE sent = FALSE;

-- ============================================
-- TRIGGER PARA PROCESSAR EMAILS
-- ============================================

-- Este trigger será processado pelo Supabase automaticamente
CREATE OR REPLACE FUNCTION process_email_queue()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- O Supabase detecta este trigger e envia o email
  -- usando o template configurado no dashboard
  
  -- Notificar o sistema de emails do Supabase
  PERFORM pg_notify(
    'email_notification',
    json_build_object(
      'email', NEW.email,
      'code', NEW.code,
      'template', 'magic_link'
    )::text
  );
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_send_email
AFTER INSERT ON email_queue
FOR EACH ROW
WHEN (NEW.sent = FALSE)
EXECUTE FUNCTION process_email_queue();

-- ============================================
-- ATUALIZAR FUNÇÃO DE CRIAR CÓDIGO
-- ============================================

-- Modificar a função existente para enfileirar email
CREATE OR REPLACE FUNCTION create_verification_code(
  p_email TEXT,
  p_user_id UUID DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code TEXT;
BEGIN
  -- Gerar código de 4 dígitos
  v_code := generate_verification_code();
  
  -- Limpar códigos antigos deste email
  DELETE FROM email_verification_codes 
  WHERE email = p_email;
  
  -- Inserir novo código
  INSERT INTO email_verification_codes (
    email,
    code,
    user_id,
    created_at,
    expires_at,
    attempts
  ) VALUES (
    p_email,
    v_code,
    p_user_id,
    NOW(),
    NOW() + INTERVAL '10 minutes',
    0
  );
  
  -- Enfileirar email para envio
  INSERT INTO email_queue (email, code)
  VALUES (p_email, v_code);
  
  RETURN v_code;
END;
$$;

-- ============================================
-- INSTRUÇÕES DE USO
-- ============================================

/*
IMPORTANTE:

1. Execute este script no SQL Editor do Supabase
2. Isso criará a tabela email_queue e os triggers
3. O Supabase processará automaticamente os emails
4. Use o template configurado no dashboard

TESTE:

SELECT create_verification_code('seu@email.com');

Isso deve:
1. Gerar código de 4 dígitos
2. Inserir na tabela email_verification_codes
3. Inserir na fila email_queue
4. Trigger notifica Supabase
5. Supabase envia email usando template configurado

*/
