-- ============================================================================
-- REESTRUTURAÇÃO COMPLETA DO BANCO DE DADOS
-- Data: 2026-01-17 18:10
-- Versão: 2.0
-- 
-- MUDANÇAS:
-- 1. Separar tabela 'users' em 4 tabelas por perfil
-- 2. Adicionar campo 'academia' em todas as tabelas
-- 3. Multi-tenancy por academia
-- 4. RLS completo em todas as tabelas
-- ============================================================================

-- ============================================================================
-- PASSO 1: REMOVER TABELA ANTIGA (SE EXISTIR)
-- ============================================================================

-- Desabilitar RLS temporariamente
ALTER TABLE IF EXISTS users DISABLE ROW LEVEL SECURITY;

-- Remover políticas antigas
DROP POLICY IF EXISTS users_select_policy ON users;
DROP POLICY IF EXISTS users_insert_policy ON users;
DROP POLICY IF EXISTS users_update_policy ON users;
DROP POLICY IF EXISTS users_delete_policy ON users;

-- Remover tabela antiga (CUIDADO: Isso apaga todos os dados!)
DROP TABLE IF EXISTS users CASCADE;

-- ============================================================================
-- PASSO 2: CRIAR NOVAS TABELAS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TABELA: users_adm (Administradores)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users_adm (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  cnpj_academia TEXT NOT NULL,  -- CNPJ da academia
  academia TEXT NOT NULL,  -- Nome da academia (multi-tenancy)
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  cnpj TEXT,  -- CNPJ do administrador (pessoa)
  cpf TEXT,
  endereco TEXT,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_users_adm_cnpj_academia ON users_adm(cnpj_academia);
CREATE INDEX IF NOT EXISTS idx_users_adm_academia ON users_adm(academia);
CREATE INDEX IF NOT EXISTS idx_users_adm_email ON users_adm(email);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_adm_updated_at
  BEFORE UPDATE ON users_adm
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- TABELA: users_nutricionista (Nutricionistas)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users_nutricionista (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  cnpj_academia TEXT NOT NULL,  -- CNPJ da academia (herda do admin)
  academia TEXT NOT NULL,  -- Nome da academia (herda do admin)
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  created_by_admin_id UUID NOT NULL REFERENCES users_adm(id) ON DELETE CASCADE,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_users_nutricionista_academia ON users_nutricionista(academia);
CREATE INDEX IF NOT EXISTS idx_users_nutricionista_admin ON users_nutricionista(created_by_admin_id);
CREATE INDEX IF NOT EXISTS idx_users_nutricionista_email ON users_nutricionista(email);

-- Trigger
CREATE TRIGGER update_users_nutricionista_updated_at
  BEFORE UPDATE ON users_nutricionista
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- TABELA: users_personal (Personal Trainers)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users_personal (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  cnpj_academia TEXT NOT NULL,  -- CNPJ da academia (herda do admin)
  academia TEXT NOT NULL,  -- Nome da academia (herda do admin)
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  created_by_admin_id UUID NOT NULL REFERENCES users_adm(id) ON DELETE CASCADE,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_users_personal_academia ON users_personal(academia);
CREATE INDEX IF NOT EXISTS idx_users_personal_admin ON users_personal(created_by_admin_id);
CREATE INDEX IF NOT EXISTS idx_users_personal_email ON users_personal(email);

-- Trigger
CREATE TRIGGER update_users_personal_updated_at
  BEFORE UPDATE ON users_personal
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- TABELA: users_alunos (Alunos)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users_alunos (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  cnpj_academia TEXT NOT NULL,  -- CNPJ da academia (herda do admin)
  academia TEXT NOT NULL,  -- Nome da academia (herda do admin)
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  created_by_admin_id UUID NOT NULL REFERENCES users_adm(id) ON DELETE CASCADE,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_users_alunos_academia ON users_alunos(academia);
CREATE INDEX IF NOT EXISTS idx_users_alunos_admin ON users_alunos(created_by_admin_id);
CREATE INDEX IF NOT EXISTS idx_users_alunos_email ON users_alunos(email);

-- Trigger
CREATE TRIGGER update_users_alunos_updated_at
  BEFORE UPDATE ON users_alunos
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- PASSO 3: HABILITAR RLS (ROW LEVEL SECURITY)
-- ============================================================================

-- Habilitar RLS em todas as tabelas
ALTER TABLE users_adm ENABLE ROW LEVEL SECURITY;
ALTER TABLE users_nutricionista ENABLE ROW LEVEL SECURITY;
ALTER TABLE users_personal ENABLE ROW LEVEL SECURITY;
ALTER TABLE users_alunos ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PASSO 4: CRIAR FUNÇÃO AUXILIAR PARA PEGAR ACADEMIA DO USUÁRIO LOGADO
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_academia()
RETURNS TEXT AS $$
DECLARE
  user_academia TEXT;
BEGIN
  -- Tentar pegar academia de cada tabela
  SELECT academia INTO user_academia FROM users_adm WHERE id = auth.uid();
  IF user_academia IS NOT NULL THEN RETURN user_academia; END IF;

  SELECT academia INTO user_academia FROM users_nutricionista WHERE id = auth.uid();
  IF user_academia IS NOT NULL THEN RETURN user_academia; END IF;

  SELECT academia INTO user_academia FROM users_personal WHERE id = auth.uid();
  IF user_academia IS NOT NULL THEN RETURN user_academia; END IF;

  SELECT academia INTO user_academia FROM users_alunos WHERE id = auth.uid();
  IF user_academia IS NOT NULL THEN RETURN user_academia; END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PASSO 5: POLÍTICAS RLS - users_adm
-- ============================================================================

-- SELECT: Admin vê apenas sua própria academia
CREATE POLICY "users_adm_select_policy" ON users_adm
FOR SELECT
USING (
  id = auth.uid() OR
  academia = get_user_academia()
);

-- INSERT: Qualquer um pode criar admin (auto-cadastro)
CREATE POLICY "users_adm_insert_policy" ON users_adm
FOR INSERT
WITH CHECK (true);

-- UPDATE: Admin só pode atualizar a si mesmo
CREATE POLICY "users_adm_update_policy" ON users_adm
FOR UPDATE
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- DELETE: Admin só pode deletar a si mesmo
CREATE POLICY "users_adm_delete_policy" ON users_adm
FOR DELETE
USING (id = auth.uid());

-- ============================================================================
-- PASSO 6: POLÍTICAS RLS - users_nutricionista
-- ============================================================================

-- SELECT: Ver apenas nutricionistas da mesma academia
CREATE POLICY "users_nutricionista_select_policy" ON users_nutricionista
FOR SELECT
USING (
  id = auth.uid() OR
  academia = get_user_academia()
);

-- INSERT: Apenas admin pode criar nutricionista
CREATE POLICY "users_nutricionista_insert_policy" ON users_nutricionista
FOR INSERT
WITH CHECK (
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid())
);

-- UPDATE: Admin ou o próprio nutricionista pode atualizar
CREATE POLICY "users_nutricionista_update_policy" ON users_nutricionista
FOR UPDATE
USING (
  id = auth.uid() OR
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid() AND academia = users_nutricionista.academia)
)
WITH CHECK (
  id = auth.uid() OR
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid() AND academia = users_nutricionista.academia)
);

-- DELETE: Apenas admin pode deletar
CREATE POLICY "users_nutricionista_delete_policy" ON users_nutricionista
FOR DELETE
USING (
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid() AND academia = users_nutricionista.academia)
);

-- ============================================================================
-- PASSO 7: POLÍTICAS RLS - users_personal
-- ============================================================================

-- SELECT: Ver apenas personals da mesma academia
CREATE POLICY "users_personal_select_policy" ON users_personal
FOR SELECT
USING (
  id = auth.uid() OR
  academia = get_user_academia()
);

-- INSERT: Apenas admin pode criar personal
CREATE POLICY "users_personal_insert_policy" ON users_personal
FOR INSERT
WITH CHECK (
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid())
);

-- UPDATE: Admin ou o próprio personal pode atualizar
CREATE POLICY "users_personal_update_policy" ON users_personal
FOR UPDATE
USING (
  id = auth.uid() OR
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid() AND academia = users_personal.academia)
)
WITH CHECK (
  id = auth.uid() OR
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid() AND academia = users_personal.academia)
);

-- DELETE: Apenas admin pode deletar
CREATE POLICY "users_personal_delete_policy" ON users_personal
FOR DELETE
USING (
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid() AND academia = users_personal.academia)
);

-- ============================================================================
-- PASSO 8: POLÍTICAS RLS - users_alunos
-- ============================================================================

-- SELECT: Ver apenas alunos da mesma academia
CREATE POLICY "users_alunos_select_policy" ON users_alunos
FOR SELECT
USING (
  id = auth.uid() OR
  academia = get_user_academia()
);

-- INSERT: Admin, nutricionista ou personal podem criar aluno
CREATE POLICY "users_alunos_insert_policy" ON users_alunos
FOR INSERT
WITH CHECK (
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid()) OR
  EXISTS (SELECT 1 FROM users_nutricionista WHERE id = auth.uid()) OR
  EXISTS (SELECT 1 FROM users_personal WHERE id = auth.uid())
);

-- UPDATE: Admin, nutricionista, personal ou o próprio aluno pode atualizar
CREATE POLICY "users_alunos_update_policy" ON users_alunos
FOR UPDATE
USING (
  id = auth.uid() OR
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid() AND academia = users_alunos.academia) OR
  EXISTS (SELECT 1 FROM users_nutricionista WHERE id = auth.uid() AND academia = users_alunos.academia) OR
  EXISTS (SELECT 1 FROM users_personal WHERE id = auth.uid() AND academia = users_alunos.academia)
)
WITH CHECK (
  id = auth.uid() OR
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid() AND academia = users_alunos.academia) OR
  EXISTS (SELECT 1 FROM users_nutricionista WHERE id = auth.uid() AND academia = users_alunos.academia) OR
  EXISTS (SELECT 1 FROM users_personal WHERE id = auth.uid() AND academia = users_alunos.academia)
);

-- DELETE: Apenas admin pode deletar
CREATE POLICY "users_alunos_delete_policy" ON users_alunos
FOR DELETE
USING (
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid() AND academia = users_alunos.academia)
);

-- ============================================================================
-- PASSO 9: AUDIT LOGS (Logs de Auditoria)
-- ============================================================================

-- Criar tabela de logs se não existir
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  action TEXT NOT NULL,
  table_name TEXT NOT NULL,
  record_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Função para log
CREATE OR REPLACE FUNCTION log_user_action()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_logs (user_id, action, table_name, record_id)
  VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id)
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Triggers de auditoria
CREATE TRIGGER audit_users_adm_changes
  AFTER INSERT OR UPDATE OR DELETE ON users_adm
  FOR EACH ROW
  EXECUTE FUNCTION log_user_action();

CREATE TRIGGER audit_users_nutricionista_changes
  AFTER INSERT OR UPDATE OR DELETE ON users_nutricionista
  FOR EACH ROW
  EXECUTE FUNCTION log_user_action();

CREATE TRIGGER audit_users_personal_changes
  AFTER INSERT OR UPDATE OR DELETE ON users_personal
  FOR EACH ROW
  EXECUTE FUNCTION log_user_action();

CREATE TRIGGER audit_users_alunos_changes
  AFTER INSERT OR UPDATE OR DELETE ON users_alunos
  FOR EACH ROW
  EXECUTE FUNCTION log_user_action();

-- ============================================================================
-- PASSO 10: ATUALIZAR TABELA DIETS PARA USAR ACADEMIA
-- ============================================================================

-- Adicionar colunas cnpj_academia e academia se não existirem
ALTER TABLE diets ADD COLUMN IF NOT EXISTS cnpj_academia TEXT;
ALTER TABLE diets ADD COLUMN IF NOT EXISTS academia TEXT;

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_diets_cnpj_academia ON diets(cnpj_academia);
CREATE INDEX IF NOT EXISTS idx_diets_academia ON diets(academia);

-- Atualizar política de SELECT para filtrar por academia
DROP POLICY IF EXISTS diets_select_policy ON diets;
CREATE POLICY "diets_select_policy" ON diets
FOR SELECT
USING (
  academia = get_user_academia() OR
  nutritionist_id = auth.uid()
);

-- ============================================================================
-- FIM DO SCRIPT
-- ============================================================================

-- Mensagem de sucesso
DO $$
BEGIN
  RAISE NOTICE '✅ Reestruturação completa do banco de dados finalizada!';
  RAISE NOTICE '✅ Tabelas criadas: users_adm, users_nutricionista, users_personal, users_alunos';
  RAISE NOTICE '✅ RLS habilitado em todas as tabelas';
  RAISE NOTICE '✅ Multi-tenancy por academia configurado';
  RAISE NOTICE '✅ Audit logs configurados';
END $$;
