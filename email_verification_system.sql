-- ============================================
-- SISTEMA DE VERIFICAÇÃO DE EMAIL COM CÓDIGO DE 4 DÍGITOS
-- Execute este script no SQL Editor do Supabase
-- ============================================

-- 1. Criar tabela para armazenar códigos de verificação
CREATE TABLE IF NOT EXISTS email_verification_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  verified BOOLEAN DEFAULT FALSE,
  attempts INT DEFAULT 0
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_verification_email ON email_verification_codes(email);
CREATE INDEX IF NOT EXISTS idx_verification_code ON email_verification_codes(code);
CREATE INDEX IF NOT EXISTS idx_verification_user ON email_verification_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_expires ON email_verification_codes(expires_at);

-- 2. Habilitar RLS
ALTER TABLE email_verification_codes ENABLE ROW LEVEL SECURITY;

-- 3. Políticas RLS
DROP POLICY IF EXISTS "Users can view own verification codes" ON email_verification_codes;
DROP POLICY IF EXISTS "System can insert verification codes" ON email_verification_codes;
DROP POLICY IF EXISTS "System can update verification codes" ON email_verification_codes;

CREATE POLICY "Users can view own verification codes" ON email_verification_codes
    FOR SELECT
    USING (email = auth.email() OR user_id = auth.uid());

CREATE POLICY "System can insert verification codes" ON email_verification_codes
    FOR INSERT
    WITH CHECK (true);

CREATE POLICY "System can update verification codes" ON email_verification_codes
    FOR UPDATE
    USING (true);

-- 4. Função para gerar código de 4 dígitos
CREATE OR REPLACE FUNCTION generate_verification_code()
RETURNS TEXT AS $$
BEGIN
    RETURN LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- 5. Função para criar código de verificação
CREATE OR REPLACE FUNCTION create_verification_code(
    p_email TEXT,
    p_user_id UUID DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_code TEXT;
    v_expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Gerar código de 4 dígitos
    v_code := generate_verification_code();
    
    -- Código expira em 10 minutos
    v_expires_at := NOW() + INTERVAL '10 minutes';
    
    -- Invalidar códigos anteriores do mesmo email
    UPDATE email_verification_codes 
    SET verified = TRUE 
    WHERE email = p_email AND verified = FALSE;
    
    -- Inserir novo código
    INSERT INTO email_verification_codes (email, code, user_id, expires_at)
    VALUES (p_email, v_code, p_user_id, v_expires_at);
    
    RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Função para verificar código
CREATE OR REPLACE FUNCTION verify_code(
    p_email TEXT,
    p_code TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_record RECORD;
BEGIN
    -- Buscar código
    SELECT * INTO v_record
    FROM email_verification_codes
    WHERE email = p_email 
    AND code = p_code 
    AND verified = FALSE
    AND expires_at > NOW()
    ORDER BY created_at DESC
    LIMIT 1;
    
    -- Se não encontrou, retorna false
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Incrementar tentativas
    UPDATE email_verification_codes
    SET attempts = attempts + 1
    WHERE id = v_record.id;
    
    -- Se passou de 5 tentativas, bloqueia
    IF v_record.attempts >= 5 THEN
        RETURN FALSE;
    END IF;
    
    -- Marcar como verificado
    UPDATE email_verification_codes
    SET verified = TRUE
    WHERE id = v_record.id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Função para limpar códigos expirados (executar periodicamente)
CREATE OR REPLACE FUNCTION cleanup_expired_verification_codes()
RETURNS VOID AS $$
BEGIN
    DELETE FROM email_verification_codes
    WHERE expires_at < NOW() - INTERVAL '1 day';
END;
$$ LANGUAGE plpgsql;

-- 8. Trigger para limpar códigos expirados automaticamente
CREATE OR REPLACE FUNCTION trigger_cleanup_verification_codes()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM cleanup_expired_verification_codes();
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_cleanup_verification ON email_verification_codes;

CREATE TRIGGER trigger_cleanup_verification
    AFTER INSERT ON email_verification_codes
    EXECUTE FUNCTION trigger_cleanup_verification_codes();

-- 9. Adicionar campo de verificação na tabela users
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE;

-- 10. Atualizar usuários existentes (não-admin) como verificados
UPDATE users SET email_verified = TRUE WHERE role != 'admin';

-- 11. Comentários
COMMENT ON TABLE email_verification_codes IS 'Armazena códigos de verificação de email de 4 dígitos';
COMMENT ON FUNCTION generate_verification_code IS 'Gera código aleatório de 4 dígitos';
COMMENT ON FUNCTION create_verification_code IS 'Cria novo código de verificação para um email';
COMMENT ON FUNCTION verify_code IS 'Verifica se o código está correto e válido';

-- Verificação
SELECT 'Sistema de verificação de email criado com sucesso!' as status;
