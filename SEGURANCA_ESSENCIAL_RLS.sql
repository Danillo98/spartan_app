-- ============================================
-- SEGURANÇA ESSENCIAL: RLS SIMPLES
-- ============================================
-- Versão simplificada: Apenas RLS, SEM auditoria
-- Foco: Proteger o banco mantendo o app funcionando
-- ============================================

-- ============================================
-- PASSO 1: CRIAR POLÍTICAS RLS SIMPLES
-- ============================================

-- ========== TABELA: USERS ==========

CREATE POLICY "users_select_policy" ON public.users
FOR SELECT
USING (
  created_by_admin_id = auth.uid() OR id = auth.uid()
);

CREATE POLICY "users_insert_policy" ON public.users
FOR INSERT
WITH CHECK (
  created_by_admin_id = auth.uid() OR id = auth.uid()
);

CREATE POLICY "users_update_policy" ON public.users
FOR UPDATE
USING (
  created_by_admin_id = auth.uid() OR id = auth.uid()
)
WITH CHECK (
  created_by_admin_id = auth.uid() OR id = auth.uid()
);

CREATE POLICY "users_delete_policy" ON public.users
FOR DELETE
USING (
  created_by_admin_id = auth.uid() AND id != auth.uid()
);


-- ========== TABELA: DIETS ==========

CREATE POLICY "diets_select_policy" ON public.diets
FOR SELECT
USING (
  created_by_admin_id = auth.uid()
  OR nutritionist_id = auth.uid()
);

CREATE POLICY "diets_insert_policy" ON public.diets
FOR INSERT
WITH CHECK (
  created_by_admin_id = auth.uid()
);

CREATE POLICY "diets_update_policy" ON public.diets
FOR UPDATE
USING (
  created_by_admin_id = auth.uid()
  OR nutritionist_id = auth.uid()
);

CREATE POLICY "diets_delete_policy" ON public.diets
FOR DELETE
USING (
  created_by_admin_id = auth.uid()
  OR nutritionist_id = auth.uid()
);


-- ========== TABELA: DIET_DAYS ==========

CREATE POLICY "diet_days_all_policy" ON public.diet_days
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.diets
    WHERE diets.id = diet_days.diet_id
      AND (diets.created_by_admin_id = auth.uid() OR diets.nutritionist_id = auth.uid())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.diets
    WHERE diets.id = diet_days.diet_id
      AND (diets.created_by_admin_id = auth.uid() OR diets.nutritionist_id = auth.uid())
  )
);


-- ========== TABELA: MEALS ==========

CREATE POLICY "meals_all_policy" ON public.meals
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.diet_days dd
    JOIN public.diets d ON dd.diet_id = d.id
    WHERE dd.id = meals.diet_day_id
      AND (d.created_by_admin_id = auth.uid() OR d.nutritionist_id = auth.uid())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.diet_days dd
    JOIN public.diets d ON dd.diet_id = d.id
    WHERE dd.id = meals.diet_day_id
      AND (d.created_by_admin_id = auth.uid() OR d.nutritionist_id = auth.uid())
  )
);


-- ========== TABELA: WORKOUTS ==========

CREATE POLICY "workouts_select_policy" ON public.workouts
FOR SELECT
USING (
  created_by_admin_id = auth.uid()
  OR trainer_id = auth.uid()
);

CREATE POLICY "workouts_insert_policy" ON public.workouts
FOR INSERT
WITH CHECK (
  created_by_admin_id = auth.uid()
);

CREATE POLICY "workouts_update_policy" ON public.workouts
FOR UPDATE
USING (
  created_by_admin_id = auth.uid()
  OR trainer_id = auth.uid()
);

CREATE POLICY "workouts_delete_policy" ON public.workouts
FOR DELETE
USING (
  created_by_admin_id = auth.uid()
  OR trainer_id = auth.uid()
);


-- ========== TABELA: WORKOUT_DAYS ==========

CREATE POLICY "workout_days_all_policy" ON public.workout_days
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.workouts
    WHERE workouts.id = workout_days.workout_id
      AND (workouts.created_by_admin_id = auth.uid() OR workouts.trainer_id = auth.uid())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.workouts
    WHERE workouts.id = workout_days.workout_id
      AND (workouts.created_by_admin_id = auth.uid() OR workouts.trainer_id = auth.uid())
  )
);


-- ========== TABELA: EXERCISES ==========

CREATE POLICY "exercises_all_policy" ON public.exercises
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.workout_days wd
    JOIN public.workouts w ON wd.workout_id = w.id
    WHERE wd.id = exercises.workout_day_id
      AND (w.created_by_admin_id = auth.uid() OR w.trainer_id = auth.uid())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.workout_days wd
    JOIN public.workouts w ON wd.workout_id = w.id
    WHERE wd.id = exercises.workout_day_id
      AND (w.created_by_admin_id = auth.uid() OR w.trainer_id = auth.uid())
  )
);


-- ========== TABELA: ACTIVE_SESSIONS ==========

CREATE POLICY "active_sessions_all_policy" ON public.active_sessions
FOR ALL
USING (
  user_id = auth.uid()
)
WITH CHECK (
  user_id = auth.uid()
);


-- ============================================
-- PASSO 2: HABILITAR RLS EM TODAS AS TABELAS
-- ============================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.active_sessions ENABLE ROW LEVEL SECURITY;

-- Tabelas de sistema SEM RLS
ALTER TABLE public.email_verification_codes DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_attempts DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.audit_logs DISABLE ROW LEVEL SECURITY;


-- ============================================
-- PASSO 3: VERIFICAÇÃO
-- ============================================

-- Ver políticas criadas
SELECT 
  tablename,
  COUNT(*) as num_policies
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

-- Ver RLS ativo
SELECT 
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('users', 'diets', 'workouts', 'diet_days', 'meals', 'workout_days', 'exercises')
ORDER BY tablename;


-- ============================================
-- FIM DO SCRIPT
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ SEGURANÇA ESSENCIAL IMPLEMENTADA!';
  RAISE NOTICE '';
  RAISE NOTICE '🔒 RLS ATIVO em 8 tabelas principais';
  RAISE NOTICE '🛡️ Políticas SIMPLES (sem recursão)';
  RAISE NOTICE '🔐 Dupla proteção (RLS + código Flutter)';
  RAISE NOTICE '';
  RAISE NOTICE '📋 TESTE AGORA (SEM FECHAR O APP):';
  RAISE NOTICE '1. Ver lista de usuários';
  RAISE NOTICE '2. Criar um novo usuário';
  RAISE NOTICE '3. Ver dashboard';
  RAISE NOTICE '';
  RAISE NOTICE '✅ Se funcionar - Perfeito!';
  RAISE NOTICE '❌ Se der erro - Execute ROLLBACK_ZEBRA.sql';
  RAISE NOTICE '';
  RAISE NOTICE '📝 NOTA: Sistema de auditoria será implementado depois';
END $$;
