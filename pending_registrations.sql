-- ============================================
-- TABELA DE CADASTROS PENDENTES
-- ============================================

-- Esta tabela armazena dados de cadastros que ainda não foram confirmados
-- Após o usuário confirmar o email, os dados são movidos para a tabela users

CREATE TABLE IF NOT EXISTS pending_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  phone TEXT NOT NULL,
  cnpj TEXT NOT NULL,
  cpf TEXT NOT NULL,
  address TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'admin',
  confirmation_token TEXT UNIQUE NOT NULL,
  token_expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  attempts INT DEFAULT 0
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_pending_email ON pending_registrations(email);
CREATE INDEX IF NOT EXISTS idx_pending_token ON pending_registrations(confirmation_token);
CREATE INDEX IF NOT EXISTS idx_pending_expires ON pending_registrations(token_expires_at);

-- ============================================
-- FUNÇÃO: CRIAR REGISTRO PENDENTE
-- ============================================

CREATE OR REPLACE FUNCTION create_pending_registration(
  p_email TEXT,
  p_name TEXT,
  p_password TEXT,
  p_phone TEXT,
  p_cnpj TEXT,
  p_cpf TEXT,
  p_address TEXT
)
RETURNS TABLE(token TEXT, expires_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_token TEXT;
  v_password_hash TEXT;
  v_expires_at TIMESTAMPTZ;
BEGIN
  -- Gerar token único de 32 caracteres
  v_token := encode(gen_random_bytes(24), 'base64');
  v_token := replace(v_token, '/', '_');
  v_token := replace(v_token, '+', '-');
  
  -- Hash da senha (será usado depois)
  v_password_hash := crypt(p_password, gen_salt('bf'));
  
  -- Expiração em 24 horas
  v_expires_at := NOW() + INTERVAL '24 hours';
  
  -- Deletar registros antigos deste email
  DELETE FROM pending_registrations WHERE email = p_email;
  
  -- Inserir novo registro pendente
  INSERT INTO pending_registrations (
    email,
    name,
    password_hash,
    phone,
    cnpj,
    cpf,
    address,
    confirmation_token,
    token_expires_at
  ) VALUES (
    p_email,
    p_name,
    v_password_hash,
    p_phone,
    p_cnpj,
    p_cpf,
    p_address,
    v_token,
    v_expires_at
  );
  
  RETURN QUERY SELECT v_token, v_expires_at;
END;
$$;

-- ============================================
-- FUNÇÃO: CONFIRMAR REGISTRO E CRIAR CONTA
-- ============================================

CREATE OR REPLACE FUNCTION confirm_registration(
  p_token TEXT
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  user_id UUID,
  email TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_pending RECORD;
  v_user_id UUID;
BEGIN
  -- Buscar registro pendente
  SELECT * INTO v_pending
  FROM pending_registrations
  WHERE confirmation_token = p_token
    AND token_expires_at > NOW();
  
  -- Verificar se token existe e não expirou
  IF v_pending IS NULL THEN
    RETURN QUERY SELECT 
      FALSE,
      'Token inválido ou expirado'::TEXT,
      NULL::UUID,
      NULL::TEXT;
    RETURN;
  END IF;
  
  -- Gerar UUID para o usuário
  v_user_id := gen_random_uuid();
  
  -- Criar conta no Supabase Auth
  -- NOTA: Isso precisa ser feito via API do Supabase, não SQL
  -- Por enquanto, apenas criamos na tabela users
  
  -- Inserir na tabela users
  INSERT INTO users (
    id,
    name,
    email,
    phone,
    password_hash,
    role,
    cnpj,
    cpf,
    address,
    email_verified,
    created_at
  ) VALUES (
    v_user_id,
    v_pending.name,
    v_pending.email,
    v_pending.phone,
    v_pending.password_hash,
    v_pending.role,
    v_pending.cnpj,
    v_pending.cpf,
    v_pending.address,
    TRUE,
    NOW()
  );
  
  -- Deletar registro pendente
  DELETE FROM pending_registrations WHERE id = v_pending.id;
  
  RETURN QUERY SELECT 
    TRUE,
    'Conta criada com sucesso!'::TEXT,
    v_user_id,
    v_pending.email;
END;
$$;

-- ============================================
-- FUNÇÃO: LIMPAR REGISTROS EXPIRADOS
-- ============================================

CREATE OR REPLACE FUNCTION cleanup_expired_registrations()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted INT;
BEGIN
  DELETE FROM pending_registrations
  WHERE token_expires_at < NOW();
  
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

-- ============================================
-- TRIGGER: LIMPAR AUTOMATICAMENTE
-- ============================================

-- Criar extensão pg_cron se disponível (opcional)
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Agendar limpeza diária (se pg_cron estiver disponível)
-- SELECT cron.schedule('cleanup-expired-registrations', '0 0 * * *', 
--   'SELECT cleanup_expired_registrations()');

-- ============================================
-- PERMISSÕES
-- ============================================

-- Permitir acesso anônimo para criar registro pendente
GRANT EXECUTE ON FUNCTION create_pending_registration TO anon, authenticated;
GRANT EXECUTE ON FUNCTION confirm_registration TO anon, authenticated;

-- ============================================
-- INSTRUÇÕES DE USO
-- ============================================

/*
1. Execute este script no SQL Editor do Supabase

2. No código Dart, use:
   - create_pending_registration() para criar registro pendente
   - confirm_registration() para confirmar e criar conta

3. O fluxo será:
   - Usuário preenche cadastro
   - Sistema cria registro pendente
   - Email enviado com link contendo token
   - Usuário clica no link
   - Sistema confirma token e cria conta
   - Usuário pode fazer login

TESTE:

-- Criar registro pendente
SELECT * FROM create_pending_registration(
  'teste@email.com',
  'Nome Teste',
  'senha123',
  '11999999999',
  '12345678901234',
  '12345678901',
  'Rua Teste, 123'
);

-- Confirmar registro (use o token retornado acima)
SELECT * FROM confirm_registration('TOKEN_AQUI');

-- Verificar usuário criado
SELECT * FROM users WHERE email = 'teste@email.com';
*/
