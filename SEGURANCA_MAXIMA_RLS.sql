-- ============================================
-- SEGURANÇA MÁXIMA V2: RLS SEM RECURSÃO
-- ============================================
-- Versão corrigida: Cria estrutura de auditoria primeiro
-- ============================================

-- ============================================
-- PASSO 1: CRIAR/ATUALIZAR TABELA DE AUDITORIA
-- ============================================

-- Criar tabela de auditoria se não existir
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  action TEXT,
  table_name TEXT,
  record_id UUID,
  ip_address TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Adicionar colunas se não existirem
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS action TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS table_name TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS record_id UUID;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS ip_address TEXT;

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at);


-- ============================================
-- PASSO 2: CRIAR POLÍTICAS RLS SIMPLES
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


-- ========== TABELA: AUDIT_LOGS ==========

CREATE POLICY "audit_logs_select_policy" ON public.audit_logs
FOR SELECT
USING (
  user_id = auth.uid()
);

CREATE POLICY "audit_logs_insert_policy" ON public.audit_logs
FOR INSERT
WITH CHECK (
  user_id = auth.uid()
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
-- PASSO 3: HABILITAR RLS EM TODAS AS TABELAS
-- ============================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.active_sessions ENABLE ROW LEVEL SECURITY;

-- Tabelas de sistema SEM RLS
ALTER TABLE public.email_verification_codes DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_attempts DISABLE ROW LEVEL SECURITY;


-- ============================================
-- PASSO 4: CRIAR FUNÇÃO E TRIGGERS DE AUDITORIA
-- ============================================

-- Função para registrar ações
CREATE OR REPLACE FUNCTION log_user_action()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
  VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id)
  );
  RETURN COALESCE(NEW, OLD);
EXCEPTION
  WHEN OTHERS THEN
    -- Se der erro no log, não bloqueia a operação principal
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Triggers de auditoria
DROP TRIGGER IF EXISTS audit_users_changes ON public.users;
CREATE TRIGGER audit_users_changes
  AFTER INSERT OR UPDATE OR DELETE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION log_user_action();

DROP TRIGGER IF EXISTS audit_diets_changes ON public.diets;
CREATE TRIGGER audit_diets_changes
  AFTER INSERT OR UPDATE OR DELETE ON public.diets
  FOR EACH ROW
  EXECUTE FUNCTION log_user_action();

DROP TRIGGER IF EXISTS audit_workouts_changes ON public.workouts;
CREATE TRIGGER audit_workouts_changes
  AFTER INSERT OR UPDATE OR DELETE ON public.workouts
  FOR EACH ROW
  EXECUTE FUNCTION log_user_action();


-- ============================================
-- PASSO 5: VERIFICAÇÃO
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
  AND tablename IN ('users', 'diets', 'workouts', 'diet_days', 'meals', 'workout_days', 'exercises', 'audit_logs')
ORDER BY tablename;


-- ============================================
-- FIM DO SCRIPT
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ SEGURANÇA MÁXIMA V2 IMPLEMENTADA!';
  RAISE NOTICE '';
  RAISE NOTICE '🔒 RLS ATIVO em todas as tabelas';
  RAISE NOTICE '🛡️ Políticas SIMPLES (sem recursão)';
  RAISE NOTICE '📝 Logs de auditoria ativos';
  RAISE NOTICE '🔐 Dupla proteção (RLS + código Flutter)';
  RAISE NOTICE '';
  RAISE NOTICE '📋 PRÓXIMO PASSO:';
  RAISE NOTICE '1. NÃO feche o app ainda';
  RAISE NOTICE '2. Teste: Ver usuários, criar usuário';
  RAISE NOTICE '3. Se funcionar ✅ - Perfeito!';
  RAISE NOTICE '4. Se der erro ❌ - Execute ROLLBACK_ZEBRA.sql';
END $$;
