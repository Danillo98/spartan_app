-- ============================================
-- EMERGÊNCIA: DESABILITAR RLS (VERSÃO CORRIGIDA)
-- ============================================
-- Remove triggers primeiro, depois funções
-- ============================================

-- PASSO 1: REMOVER TRIGGERS PRIMEIRO
DROP TRIGGER IF EXISTS trigger_set_created_by_admin ON public.users;
DROP TRIGGER IF EXISTS trigger_set_created_by_admin_diets ON public.diets;
DROP TRIGGER IF EXISTS trigger_set_created_by_admin_workouts ON public.workouts;
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;

-- PASSO 2: REMOVER FUNÇÕES
DROP FUNCTION IF EXISTS set_created_by_admin_users() CASCADE;
DROP FUNCTION IF EXISTS set_created_by_admin_diets() CASCADE;
DROP FUNCTION IF EXISTS set_created_by_admin_workouts() CASCADE;
DROP FUNCTION IF EXISTS set_created_by_admin() CASCADE;
DROP FUNCTION IF EXISTS get_current_user_role() CASCADE;
DROP FUNCTION IF EXISTS get_current_user_admin_id() CASCADE;

-- PASSO 3: DESABILITAR RLS EM TODAS AS TABELAS
ALTER TABLE IF EXISTS public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.diets DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.diet_days DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.meals DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.workouts DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.workout_days DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.exercises DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.email_verification_codes DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.login_attempts DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.active_sessions DISABLE ROW LEVEL SECURITY;

-- PASSO 4: REMOVER TODAS AS POLÍTICAS
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT schemaname, tablename, policyname 
              FROM pg_policies 
              WHERE schemaname = 'public') 
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', 
                      r.policyname, r.schemaname, r.tablename);
    END LOOP;
END $$;

-- PASSO 5: VERIFICAR
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public'
  AND tablename IN ('users', 'diets', 'workouts', 'diet_days', 'meals', 'workout_days', 'exercises')
ORDER BY tablename;

-- Deve mostrar rowsecurity = false para todas

-- PASSO 6: GARANTIR QUE created_by_admin_id EXISTE E ESTÁ PREENCHIDO
-- (Não remove a coluna, apenas garante que está preenchida)

-- Admins são criadores de si mesmos
UPDATE public.users 
SET created_by_admin_id = id 
WHERE role = 'admin' AND (created_by_admin_id IS NULL OR created_by_admin_id != id);

-- Outros usuários: atribuir ao primeiro admin
UPDATE public.users 
SET created_by_admin_id = (
  SELECT id FROM public.users WHERE role = 'admin' ORDER BY created_at LIMIT 1
)
WHERE created_by_admin_id IS NULL AND role != 'admin';

-- Verificar se todos têm admin_id
SELECT 
  role,
  COUNT(*) as total,
  COUNT(created_by_admin_id) as com_admin_id,
  COUNT(*) - COUNT(created_by_admin_id) as sem_admin_id
FROM public.users
GROUP BY role;

-- MENSAGEM FINAL
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ RLS DESABILITADO COM SUCESSO!';
  RAISE NOTICE '✅ Triggers e funções removidos';
  RAISE NOTICE '✅ Políticas removidas';
  RAISE NOTICE '✅ created_by_admin_id preenchido';
  RAISE NOTICE '';
  RAISE NOTICE '� PRÓXIMO PASSO:';
  RAISE NOTICE '1. Feche o app completamente';
  RAISE NOTICE '2. Abra novamente';
  RAISE NOTICE '3. Faça login';
  RAISE NOTICE '4. Deve funcionar sem erro!';
  RAISE NOTICE '';
  RAISE NOTICE '� ISOLAMENTO:';
  RAISE NOTICE 'O isolamento agora é feito no código Flutter';
  RAISE NOTICE 'UserService já foi atualizado com filtros manuais';
END $$;
