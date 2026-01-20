-- ============================================
-- ROLLBACK: VOLTAR AO ESTADO ZEBRA
-- ============================================
-- Use APENAS se der erro após executar SEGURANCA_MAXIMA_RLS.sql
-- ============================================

-- DESABILITAR RLS
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.diets DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_days DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.meals DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_days DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.active_sessions DISABLE ROW LEVEL SECURITY;

-- REMOVER POLÍTICAS
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

-- REMOVER TRIGGERS DE AUDITORIA
DROP TRIGGER IF EXISTS audit_users_changes ON public.users;
DROP TRIGGER IF EXISTS audit_diets_changes ON public.diets;
DROP TRIGGER IF EXISTS audit_workouts_changes ON public.workouts;

-- REMOVER FUNÇÃO DE AUDITORIA
DROP FUNCTION IF EXISTS log_user_action() CASCADE;

-- VERIFICAR
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

DO $$
BEGIN
  RAISE NOTICE '✅ ROLLBACK COMPLETO!';
  RAISE NOTICE '📱 Voltou ao estado ZEBRA';
  RAISE NOTICE '🔒 RLS desabilitado';
  RAISE NOTICE '🛡️ Isolamento via código Flutter apenas';
END $$;
