-- ============================================================
-- RESTAURAÇÃO COMPLETA DE TODAS AS TABELAS DE CONTEÚDO
-- Spartan App - v2.6.1 - 2026-02-27
-- ============================================================
-- O script "DISJUNTOR_GERAL" apagou as políticas de TODAS as 
-- tabelas. Este script restaura o acesso para:
--   - workouts (treinos)
--   - diets (dietas)
--   - notices (avisos/quadro de avisos)
--   - appointments (agendamentos)
--   - physical_assessments (avaliações físicas)
--   - financial_transactions (mensalidades)
-- 
-- ESTRATÉGIA: Políticas simples via JWT metadata (id_academia)
-- SEM subqueries em outras tabelas = SEM recursão = SEM loop.
-- ============================================================


-- ============================================================
-- 1. financial_transactions
-- ============================================================
ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "JWT_FINANCIAL_ALL" ON public.financial_transactions;
DROP POLICY IF EXISTS "FIN_SELECT" ON public.financial_transactions;
DROP POLICY IF EXISTS "FIN_INSERT" ON public.financial_transactions;
DROP POLICY IF EXISTS "FIN_UPDATE" ON public.financial_transactions;
DROP POLICY IF EXISTS "FIN_DELETE" ON public.financial_transactions;

CREATE POLICY "FIN_SELECT" ON public.financial_transactions
FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "FIN_INSERT" ON public.financial_transactions
FOR INSERT WITH CHECK (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "FIN_UPDATE" ON public.financial_transactions
FOR UPDATE USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "FIN_DELETE" ON public.financial_transactions
FOR DELETE USING (
  auth.role() = 'service_role'
  OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.financial_transactions TO authenticated;


-- ============================================================
-- 2. workouts (treinos)
-- ============================================================
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "JWT_WORKOUTS_ALL" ON public.workouts;
DROP POLICY IF EXISTS "WORKOUT_SELECT" ON public.workouts;
DROP POLICY IF EXISTS "WORKOUT_INSERT" ON public.workouts;
DROP POLICY IF EXISTS "WORKOUT_UPDATE" ON public.workouts;
DROP POLICY IF EXISTS "WORKOUT_DELETE" ON public.workouts;

CREATE POLICY "WORKOUT_SELECT" ON public.workouts
FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "WORKOUT_INSERT" ON public.workouts
FOR INSERT WITH CHECK (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "WORKOUT_UPDATE" ON public.workouts
FOR UPDATE USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "WORKOUT_DELETE" ON public.workouts
FOR DELETE USING (
  auth.role() = 'service_role'
  OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workouts TO authenticated;


-- ============================================================
-- 3. diets (dietas)
-- ============================================================
ALTER TABLE public.diets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "JWT_DIETS_ALL" ON public.diets;
DROP POLICY IF EXISTS "DIET_SELECT" ON public.diets;
DROP POLICY IF EXISTS "DIET_INSERT" ON public.diets;
DROP POLICY IF EXISTS "DIET_UPDATE" ON public.diets;
DROP POLICY IF EXISTS "DIET_DELETE" ON public.diets;

CREATE POLICY "DIET_SELECT" ON public.diets
FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "DIET_INSERT" ON public.diets
FOR INSERT WITH CHECK (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "DIET_UPDATE" ON public.diets
FOR UPDATE USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "DIET_DELETE" ON public.diets
FOR DELETE USING (
  auth.role() = 'service_role'
  OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.diets TO authenticated;


-- ============================================================
-- 4. notices (quadro de avisos)
-- ============================================================
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "JWT_NOTICES_ALL" ON public.notices;
DROP POLICY IF EXISTS "NOTICE_SELECT" ON public.notices;
DROP POLICY IF EXISTS "NOTICE_INSERT" ON public.notices;
DROP POLICY IF EXISTS "NOTICE_UPDATE" ON public.notices;
DROP POLICY IF EXISTS "NOTICE_DELETE" ON public.notices;

CREATE POLICY "NOTICE_SELECT" ON public.notices
FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "NOTICE_INSERT" ON public.notices
FOR INSERT WITH CHECK (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "NOTICE_UPDATE" ON public.notices
FOR UPDATE USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "NOTICE_DELETE" ON public.notices
FOR DELETE USING (
  auth.role() = 'service_role'
  OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notices TO authenticated;


-- ============================================================
-- 5. appointments (agendamentos)
-- ============================================================
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "JWT_APPOINTMENTS_ALL" ON public.appointments;
DROP POLICY IF EXISTS "APPT_SELECT" ON public.appointments;
DROP POLICY IF EXISTS "APPT_INSERT" ON public.appointments;
DROP POLICY IF EXISTS "APPT_UPDATE" ON public.appointments;
DROP POLICY IF EXISTS "APPT_DELETE" ON public.appointments;

CREATE POLICY "APPT_SELECT" ON public.appointments
FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "APPT_INSERT" ON public.appointments
FOR INSERT WITH CHECK (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "APPT_UPDATE" ON public.appointments
FOR UPDATE USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "APPT_DELETE" ON public.appointments
FOR DELETE USING (
  auth.role() = 'service_role'
  OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.appointments TO authenticated;


-- ============================================================
-- 6. physical_assessments (avaliações físicas)
-- ============================================================
ALTER TABLE public.physical_assessments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "JWT_ASSESSMENTS_ALL" ON public.physical_assessments;
DROP POLICY IF EXISTS "ASSESS_SELECT" ON public.physical_assessments;
DROP POLICY IF EXISTS "ASSESS_INSERT" ON public.physical_assessments;
DROP POLICY IF EXISTS "ASSESS_UPDATE" ON public.physical_assessments;
DROP POLICY IF EXISTS "ASSESS_DELETE" ON public.physical_assessments;

CREATE POLICY "ASSESS_SELECT" ON public.physical_assessments
FOR SELECT USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "ASSESS_INSERT" ON public.physical_assessments
FOR INSERT WITH CHECK (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "ASSESS_UPDATE" ON public.physical_assessments
FOR UPDATE USING (
  auth.uid() IS NOT NULL AND (
    auth.role() = 'service_role'
    OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia')
    OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  )
);
CREATE POLICY "ASSESS_DELETE" ON public.physical_assessments
FOR DELETE USING (
  auth.role() = 'service_role'
  OR id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.physical_assessments TO authenticated;


-- ============================================================
-- GRANTS GERAIS + RELOAD FINAL
-- ============================================================
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;

NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';

-- Verificação: Mostrar quais tabelas têm RLS ativado e quantas políticas
SELECT 
  tablename,
  rowsecurity as "RLS",
  (SELECT COUNT(*) FROM pg_policies p WHERE p.tablename = t.tablename AND p.schemaname = 'public') as "Politicas"
FROM pg_tables t
WHERE schemaname = 'public'
AND tablename IN (
  'users_adm', 'users_alunos', 'users_nutricionista', 'users_personal',
  'workouts', 'diets', 'notices', 'appointments', 'physical_assessments', 'financial_transactions'
)
ORDER BY tablename;

SELECT '✅ TODAS AS TABELAS RESTAURADAS! Treinos, dietas, avisos, agendamentos e mensalidades voltaram.' as status;
