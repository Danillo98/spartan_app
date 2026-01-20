-- ============================================
-- POLÍTICAS DE SEGURANÇA AVANÇADAS - SPARTAN APP
-- Execute este script no SQL Editor do Supabase
-- ============================================

-- ============================================
-- 1. TABELA DE LOGS DE AUDITORIA
-- ============================================

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'error', 'critical')),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  target_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  description TEXT,
  metadata JSONB,
  ip_address TEXT,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para melhorar performance de consultas
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX idx_audit_logs_severity ON audit_logs(severity);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp DESC);
CREATE INDEX idx_audit_logs_target_user ON audit_logs(target_user_id);

-- ============================================
-- 2. TABELA DE TENTATIVAS DE LOGIN
-- ============================================

CREATE TABLE IF NOT EXISTS login_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  ip_address TEXT,
  success BOOLEAN NOT NULL,
  failure_reason TEXT,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_login_attempts_email ON login_attempts(email);
CREATE INDEX idx_login_attempts_timestamp ON login_attempts(timestamp DESC);
CREATE INDEX idx_login_attempts_ip ON login_attempts(ip_address);

-- ============================================
-- 3. TABELA DE SESSÕES ATIVAS
-- ============================================

CREATE TABLE IF NOT EXISTS active_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_token TEXT NOT NULL UNIQUE,
  ip_address TEXT,
  user_agent TEXT,
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Índices
CREATE INDEX idx_active_sessions_user_id ON active_sessions(user_id);
CREATE INDEX idx_active_sessions_token ON active_sessions(session_token);
CREATE INDEX idx_active_sessions_expires ON active_sessions(expires_at);

-- ============================================
-- 4. POLÍTICAS RLS PARA AUDIT LOGS
-- ============================================

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Admin pode ver todos os logs
CREATE POLICY "Admin can view all audit logs" ON audit_logs
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Usuários podem ver apenas seus próprios logs
CREATE POLICY "Users can view own audit logs" ON audit_logs
    FOR SELECT
    USING (user_id = auth.uid());

-- Apenas sistema pode inserir logs (via service role)
CREATE POLICY "System can insert audit logs" ON audit_logs
    FOR INSERT
    WITH CHECK (true);

-- ============================================
-- 5. POLÍTICAS RLS PARA LOGIN ATTEMPTS
-- ============================================

ALTER TABLE login_attempts ENABLE ROW LEVEL SECURITY;

-- Admin pode ver todas as tentativas
CREATE POLICY "Admin can view all login attempts" ON login_attempts
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Sistema pode inserir tentativas
CREATE POLICY "System can insert login attempts" ON login_attempts
    FOR INSERT
    WITH CHECK (true);

-- ============================================
-- 6. POLÍTICAS RLS PARA SESSÕES ATIVAS
-- ============================================

ALTER TABLE active_sessions ENABLE ROW LEVEL SECURITY;

-- Usuários podem ver apenas suas próprias sessões
CREATE POLICY "Users can view own sessions" ON active_sessions
    FOR SELECT
    USING (user_id = auth.uid());

-- Usuários podem deletar suas próprias sessões (logout)
CREATE POLICY "Users can delete own sessions" ON active_sessions
    FOR DELETE
    USING (user_id = auth.uid());

-- Admin pode ver todas as sessões
CREATE POLICY "Admin can view all sessions" ON active_sessions
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- ============================================
-- 7. FUNÇÕES DE SEGURANÇA
-- ============================================

-- Função para validar CPF
CREATE OR REPLACE FUNCTION validate_cpf(cpf TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    cpf_clean TEXT;
    sum INT;
    digit1 INT;
    digit2 INT;
BEGIN
    -- Remove caracteres não numéricos
    cpf_clean := regexp_replace(cpf, '[^0-9]', '', 'g');
    
    -- Verifica se tem 11 dígitos
    IF length(cpf_clean) != 11 THEN
        RETURN FALSE;
    END IF;
    
    -- Verifica se todos os dígitos são iguais
    IF cpf_clean ~ '^(\d)\1{10}$' THEN
        RETURN FALSE;
    END IF;
    
    -- Validação do primeiro dígito
    sum := 0;
    FOR i IN 1..9 LOOP
        sum := sum + (substring(cpf_clean, i, 1)::INT * (11 - i));
    END LOOP;
    digit1 := 11 - (sum % 11);
    IF digit1 >= 10 THEN
        digit1 := 0;
    END IF;
    IF digit1 != substring(cpf_clean, 10, 1)::INT THEN
        RETURN FALSE;
    END IF;
    
    -- Validação do segundo dígito
    sum := 0;
    FOR i IN 1..10 LOOP
        sum := sum + (substring(cpf_clean, i, 1)::INT * (12 - i));
    END LOOP;
    digit2 := 11 - (sum % 11);
    IF digit2 >= 10 THEN
        digit2 := 0;
    END IF;
    IF digit2 != substring(cpf_clean, 11, 1)::INT THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Função para validar CNPJ
CREATE OR REPLACE FUNCTION validate_cnpj(cnpj TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    cnpj_clean TEXT;
    sum INT;
    digit1 INT;
    digit2 INT;
    weights1 INT[] := ARRAY[5,4,3,2,9,8,7,6,5,4,3,2];
    weights2 INT[] := ARRAY[6,5,4,3,2,9,8,7,6,5,4,3,2];
BEGIN
    -- Remove caracteres não numéricos
    cnpj_clean := regexp_replace(cnpj, '[^0-9]', '', 'g');
    
    -- Verifica se tem 14 dígitos
    IF length(cnpj_clean) != 14 THEN
        RETURN FALSE;
    END IF;
    
    -- Verifica se todos os dígitos são iguais
    IF cnpj_clean ~ '^(\d)\1{13}$' THEN
        RETURN FALSE;
    END IF;
    
    -- Validação do primeiro dígito
    sum := 0;
    FOR i IN 1..12 LOOP
        sum := sum + (substring(cnpj_clean, i, 1)::INT * weights1[i]);
    END LOOP;
    digit1 := CASE WHEN sum % 11 < 2 THEN 0 ELSE 11 - (sum % 11) END;
    IF digit1 != substring(cnpj_clean, 13, 1)::INT THEN
        RETURN FALSE;
    END IF;
    
    -- Validação do segundo dígito
    sum := 0;
    FOR i IN 1..13 LOOP
        sum := sum + (substring(cnpj_clean, i, 1)::INT * weights2[i]);
    END LOOP;
    digit2 := CASE WHEN sum % 11 < 2 THEN 0 ELSE 11 - (sum % 11) END;
    IF digit2 != substring(cnpj_clean, 14, 1)::INT THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 8. CONSTRAINTS DE VALIDAÇÃO
-- ============================================

-- Adiciona validação de CPF na tabela users
ALTER TABLE users ADD CONSTRAINT check_valid_cpf 
    CHECK (cpf IS NULL OR validate_cpf(cpf));

-- Adiciona validação de CNPJ na tabela users
ALTER TABLE users ADD CONSTRAINT check_valid_cnpj 
    CHECK (cnpj IS NULL OR validate_cnpj(cnpj));

-- Adiciona validação de email
ALTER TABLE users ADD CONSTRAINT check_valid_email 
    CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- ============================================
-- 9. TRIGGER PARA LIMPAR SESSÕES EXPIRADAS
-- ============================================

CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM active_sessions WHERE expires_at < NOW();
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cleanup_expired_sessions
    AFTER INSERT ON active_sessions
    EXECUTE FUNCTION cleanup_expired_sessions();

-- ============================================
-- 10. FUNÇÃO PARA REGISTRAR TENTATIVA DE LOGIN
-- ============================================

CREATE OR REPLACE FUNCTION log_login_attempt(
    p_email TEXT,
    p_ip_address TEXT,
    p_success BOOLEAN,
    p_failure_reason TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO login_attempts (email, ip_address, success, failure_reason)
    VALUES (p_email, p_ip_address, p_success, p_failure_reason);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 11. POLÍTICAS ADICIONAIS PARA TABELA USERS
-- ============================================

-- Impede que usuários vejam senhas de outros
CREATE POLICY "Users cannot see password hashes" ON users
    FOR SELECT
    USING (true)
    WITH CHECK (false);

-- Nutricionistas podem ver apenas alunos
CREATE POLICY "Nutritionists can view students" ON users
    FOR SELECT
    USING (
        (auth.uid() IN (SELECT id FROM users WHERE role = 'nutritionist'))
        AND role = 'student'
    );

-- Trainers podem ver apenas alunos
CREATE POLICY "Trainers can view students" ON users
    FOR SELECT
    USING (
        (auth.uid() IN (SELECT id FROM users WHERE role = 'trainer'))
        AND role = 'student'
    );

-- ============================================
-- 12. POLÍTICAS PARA DIETAS E TREINOS
-- ============================================

-- Impede que nutricionistas vejam dietas de outros nutricionistas
CREATE POLICY "Nutritionists isolation" ON diets
    FOR SELECT
    USING (
        nutritionist_id = auth.uid() 
        OR student_id = auth.uid()
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

-- Impede que trainers vejam treinos de outros trainers
CREATE POLICY "Trainers isolation" ON workouts
    FOR SELECT
    USING (
        trainer_id = auth.uid() 
        OR student_id = auth.uid()
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================
-- 13. ÍNDICES ADICIONAIS PARA PERFORMANCE
-- ============================================

-- Índice para busca rápida de usuários por role
CREATE INDEX IF NOT EXISTS idx_users_role_email ON users(role, email);

-- Índice para busca de dietas ativas
CREATE INDEX IF NOT EXISTS idx_diets_active ON diets(student_id, year, month);

-- Índice para busca de treinos ativos
CREATE INDEX IF NOT EXISTS idx_workouts_active ON workouts(student_id, start_date, end_date);

-- ============================================
-- 14. COMENTÁRIOS PARA DOCUMENTAÇÃO
-- ============================================

COMMENT ON TABLE audit_logs IS 'Registra todas as ações importantes do sistema para auditoria';
COMMENT ON TABLE login_attempts IS 'Registra todas as tentativas de login para detectar ataques';
COMMENT ON TABLE active_sessions IS 'Gerencia sessões ativas de usuários';

COMMENT ON FUNCTION validate_cpf IS 'Valida CPF brasileiro com dígitos verificadores';
COMMENT ON FUNCTION validate_cnpj IS 'Valida CNPJ brasileiro com dígitos verificadores';
COMMENT ON FUNCTION log_login_attempt IS 'Registra tentativa de login no sistema';

-- ============================================
-- FIM DO SCRIPT
-- ============================================

-- Para verificar se tudo foi criado corretamente:
SELECT 'Tabelas criadas:' as status;
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('audit_logs', 'login_attempts', 'active_sessions');

SELECT 'Funções criadas:' as status;
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('validate_cpf', 'validate_cnpj', 'log_login_attempt');
