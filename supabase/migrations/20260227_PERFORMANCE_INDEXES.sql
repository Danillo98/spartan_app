-- ============================================================
-- ÍNDICES DE PERFORMANCE - SPARTAN APP
-- Objetivo: Fazer TODAS as telas carregar instantaneamente
-- Todas as queries usam id_academia como filtro principal
-- ============================================================

-- ============================================================
-- TABELA: users_alunos
-- Queries: WHERE id_academia = ? | WHERE id = ?
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_users_alunos_id_academia
  ON public.users_alunos (id_academia);

CREATE INDEX IF NOT EXISTS idx_users_alunos_email
  ON public.users_alunos (email);

CREATE INDEX IF NOT EXISTS idx_users_alunos_id_academia_nome
  ON public.users_alunos (id_academia, nome);

-- ============================================================
-- TABELA: users_personal
-- Queries: WHERE id_academia = ? | WHERE id = ?
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_users_personal_id_academia
  ON public.users_personal (id_academia);

CREATE INDEX IF NOT EXISTS idx_users_personal_email
  ON public.users_personal (email);

-- ============================================================
-- TABELA: users_nutricionista
-- Queries: WHERE id_academia = ? | WHERE id = ?
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_users_nutricionista_id_academia
  ON public.users_nutricionista (id_academia);

CREATE INDEX IF NOT EXISTS idx_users_nutricionista_email
  ON public.users_nutricionista (email);

-- ============================================================
-- TABELA: workouts
-- Queries: WHERE id_academia = ? | WHERE student_id = ? | WHERE personal_id = ?
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_workouts_id_academia
  ON public.workouts (id_academia);

CREATE INDEX IF NOT EXISTS idx_workouts_student_id
  ON public.workouts (student_id);

CREATE INDEX IF NOT EXISTS idx_workouts_personal_id
  ON public.workouts (personal_id);

CREATE INDEX IF NOT EXISTS idx_workouts_id_academia_created_at
  ON public.workouts (id_academia, created_at DESC);

-- ============================================================
-- TABELA: workout_templates
-- Queries: WHERE id_academia = ? | WHERE personal_id = ?
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_workout_templates_id_academia
  ON public.workout_templates (id_academia);

CREATE INDEX IF NOT EXISTS idx_workout_templates_personal_id
  ON public.workout_templates (personal_id);

-- ============================================================
-- TABELA: workout_days
-- Queries: WHERE workout_id = ?
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_workout_days_workout_id
  ON public.workout_days (workout_id);

-- ============================================================
-- TABELA: workout_exercises
-- Queries: WHERE day_id = ? | WHERE day_id IN (...)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_workout_exercises_day_id
  ON public.workout_exercises (day_id);

-- ============================================================
-- TABELA: diets
-- Queries: WHERE id_academia = ? | WHERE student_id = ? | WHERE nutritionist_id = ?
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_diets_id_academia
  ON public.diets (id_academia);

CREATE INDEX IF NOT EXISTS idx_diets_student_id
  ON public.diets (student_id);

CREATE INDEX IF NOT EXISTS idx_diets_nutritionist_id
  ON public.diets (nutritionist_id);

CREATE INDEX IF NOT EXISTS idx_diets_id_academia_created_at
  ON public.diets (id_academia, created_at DESC);

-- ============================================================
-- TABELA: physical_assessments
-- Queries: WHERE id_academia = ? | WHERE student_id = ?
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_physical_assessments_id_academia
  ON public.physical_assessments (id_academia);

CREATE INDEX IF NOT EXISTS idx_physical_assessments_student_id
  ON public.physical_assessments (student_id);

-- ============================================================
-- TABELA: financial_transactions
-- Queries: WHERE id_academia = ? | WHERE related_user_id = ?
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_financial_transactions_id_academia
  ON public.financial_transactions (id_academia);

CREATE INDEX IF NOT EXISTS idx_financial_transactions_related_user_id
  ON public.financial_transactions (related_user_id);

CREATE INDEX IF NOT EXISTS idx_financial_transactions_date
  ON public.financial_transactions (id_academia, transaction_date DESC);

-- ============================================================
-- TABELA: notices / appointments
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_notices_id_academia
  ON public.notices (id_academia);

CREATE INDEX IF NOT EXISTS idx_appointments_id_academia
  ON public.appointments (id_academia);

-- ============================================================
-- TABELA: notifications
-- Queries: WHERE user_id = ?
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_notifications_user_id
  ON public.notifications (user_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id_is_read
  ON public.notifications (user_id, is_read);

-- ============================================================
-- FIX: RLS WORKOUT_TEMPLATES - Garantir que templates aparecem
-- ============================================================
ALTER TABLE public.workout_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "workout_templates_select" ON public.workout_templates;
DROP POLICY IF EXISTS "workout_templates_insert" ON public.workout_templates;
DROP POLICY IF EXISTS "workout_templates_update" ON public.workout_templates;
DROP POLICY IF EXISTS "workout_templates_delete" ON public.workout_templates;

-- SELECT: Personal/Admin vê templates da mesma academia
CREATE POLICY "workout_templates_select" ON public.workout_templates
  FOR SELECT USING (
    id_academia = (
      auth.jwt() -> 'user_metadata' ->> 'id_academia'
    )::uuid
    OR
    id_academia = auth.uid()
  );

-- INSERT: Apenas da própria academia
CREATE POLICY "workout_templates_insert" ON public.workout_templates
  FOR INSERT WITH CHECK (
    id_academia = (
      auth.jwt() -> 'user_metadata' ->> 'id_academia'
    )::uuid
    OR
    id_academia = auth.uid()
  );

-- UPDATE/DELETE: Próprio criador ou admin da academia
CREATE POLICY "workout_templates_update" ON public.workout_templates
  FOR UPDATE USING (
    id_academia = (
      auth.jwt() -> 'user_metadata' ->> 'id_academia'
    )::uuid
    OR
    id_academia = auth.uid()
  );

CREATE POLICY "workout_templates_delete" ON public.workout_templates
  FOR DELETE USING (
    id_academia = (
      auth.jwt() -> 'user_metadata' ->> 'id_academia'
    )::uuid
    OR
    id_academia = auth.uid()
  );

SELECT 'Índices de performance e RLS de workout_templates criados com sucesso!' AS resultado;
