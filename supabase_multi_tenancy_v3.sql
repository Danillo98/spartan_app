-- ============================================
-- SCRIPT DE MIGRAÇÃO: MULTI-TENANCY V3
-- ============================================
-- Data: 2026-01-17
-- Objetivo: Implementar isolamento de dados entre administradores
-- VERSÃO 3: Corrige recursão infinita nas políticas RLS
-- IMPORTANTE: Execute este script no SQL Editor do Supabase
-- ============================================

-- ============================================
-- PASSO 1: DESABILITAR RLS TEMPORARIAMENTE
-- ============================================

-- Desabilitar RLS para evitar problemas durante a migração
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Admins veem apenas seus usuários" ON public.users;
DROP POLICY IF EXISTS "Admins criam usuários com seu ID" ON public.users;
DROP POLICY IF EXISTS "Admins atualizam apenas seus usuários" ON public.users;
DROP POLICY IF EXISTS "Admins deletam apenas seus usuários" ON public.users;
DROP POLICY IF EXISTS "Usuários veem próprios dados" ON public.users;


-- ============================================
-- PASSO 2: ADICIONAR COLUNA created_by_admin_id
-- ============================================

-- Adicionar coluna para rastrear qual admin criou cada usuário
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS created_by_admin_id UUID REFERENCES auth.users(id);

-- Criar índice para melhorar performance nas consultas
CREATE INDEX IF NOT EXISTS idx_users_created_by_admin 
ON public.users(created_by_admin_id);

COMMENT ON COLUMN public.users.created_by_admin_id IS 
'ID do administrador que criou este usuário. Para admins, aponta para si mesmo.';


-- ============================================
-- PASSO 3: MIGRAR DADOS EXISTENTES
-- ============================================

-- Atualizar admins existentes (cada admin é criador de si mesmo)
UPDATE public.users 
SET created_by_admin_id = id 
WHERE role = 'admin' AND created_by_admin_id IS NULL;

-- Atribuir usuários órfãos ao primeiro admin encontrado
UPDATE public.users 
SET created_by_admin_id = (
  SELECT id FROM public.users WHERE role = 'admin' ORDER BY created_at LIMIT 1
)
WHERE created_by_admin_id IS NULL AND role != 'admin';


-- ============================================
-- PASSO 4: CRIAR FUNÇÃO E TRIGGER
-- ============================================

-- Função para auto-preencher created_by_admin_id ao inserir novos usuários
CREATE OR REPLACE FUNCTION set_created_by_admin()
RETURNS TRIGGER AS $$
BEGIN
  -- Se o usuário sendo criado não for admin, preenche com o ID do admin atual
  IF NEW.role != 'admin' THEN
    NEW.created_by_admin_id := auth.uid();
  END IF;
  
  -- Se o usuário sendo criado FOR admin, ele é seu próprio "criador"
  IF NEW.role = 'admin' THEN
    NEW.created_by_admin_id := NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Criar trigger (remove se já existir)
DROP TRIGGER IF EXISTS trigger_set_created_by_admin ON public.users;

CREATE TRIGGER trigger_set_created_by_admin
  BEFORE INSERT ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION set_created_by_admin();


-- ============================================
-- PASSO 5: CRIAR POLÍTICAS RLS (SEM RECURSÃO)
-- ============================================

-- POLÍTICA 1: SELECT (Visualização)
-- Usa SECURITY DEFINER para evitar recursão
CREATE POLICY "Admins veem apenas seus usuários"
ON public.users
FOR SELECT
USING (
  -- Caso 1: Admin vê usuários que criou
  created_by_admin_id = auth.uid()
  OR
  -- Caso 2: Usuário vê seus próprios dados
  id = auth.uid()
);


-- POLÍTICA 2: INSERT (Criação)
CREATE POLICY "Admins criam usuários com seu ID"
ON public.users
FOR INSERT
WITH CHECK (
  -- O created_by_admin_id deve ser o ID do usuário atual ou o próprio ID (para admins)
  created_by_admin_id = auth.uid() OR id = auth.uid()
);


-- POLÍTICA 3: UPDATE (Atualização)
CREATE POLICY "Admins atualizam apenas seus usuários"
ON public.users
FOR UPDATE
USING (
  -- Admin pode atualizar usuários que criou OU usuário pode atualizar a si mesmo
  created_by_admin_id = auth.uid() OR id = auth.uid()
);


-- POLÍTICA 4: DELETE (Exclusão)
CREATE POLICY "Admins deletam apenas seus usuários"
ON public.users
FOR DELETE
USING (
  -- Apenas pode deletar usuários que criou (não pode deletar a si mesmo por segurança)
  created_by_admin_id = auth.uid() AND id != auth.uid()
);


-- ============================================
-- PASSO 6: REABILITAR RLS
-- ============================================

-- Habilitar RLS na tabela users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;


-- ============================================
-- PASSO 7: VERIFICAÇÃO E TESTES
-- ============================================

-- Verificar se a coluna foi criada
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'created_by_admin_id';

-- Verificar se todos os usuários têm created_by_admin_id preenchido
SELECT 
  role,
  COUNT(*) as total,
  COUNT(created_by_admin_id) as com_admin_id,
  COUNT(*) - COUNT(created_by_admin_id) as sem_admin_id
FROM public.users
GROUP BY role;

-- Verificar políticas RLS
SELECT schemaname, tablename, policyname, permissive, cmd
FROM pg_policies
WHERE tablename = 'users';

-- Verificar trigger
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'users';


-- ============================================
-- ROLLBACK (Use apenas se precisar reverter)
-- ============================================

-- ATENÇÃO: Descomente apenas se precisar reverter as mudanças

-- ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
-- DROP TRIGGER IF EXISTS trigger_set_created_by_admin ON public.users;
-- DROP FUNCTION IF EXISTS set_created_by_admin();
-- DROP POLICY IF EXISTS "Admins veem apenas seus usuários" ON public.users;
-- DROP POLICY IF EXISTS "Admins criam usuários com seu ID" ON public.users;
-- DROP POLICY IF EXISTS "Admins atualizam apenas seus usuários" ON public.users;
-- DROP POLICY IF EXISTS "Admins deletam apenas seus usuários" ON public.users;
-- ALTER TABLE public.users DROP COLUMN IF EXISTS created_by_admin_id;


-- ============================================
-- FIM DO SCRIPT
-- ============================================

-- Mensagem de sucesso
DO $$
BEGIN
  RAISE NOTICE '✅ Script de Multi-Tenancy V3 executado com sucesso!';
  RAISE NOTICE '📋 Coluna created_by_admin_id criada e populada';
  RAISE NOTICE '🔒 RLS ativado com políticas simplificadas';
  RAISE NOTICE '🧪 Próximo passo: Testar login com admin existente';
END $$;
