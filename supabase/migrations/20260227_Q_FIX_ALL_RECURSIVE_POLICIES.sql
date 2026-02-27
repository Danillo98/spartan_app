-- ============================================================
-- FIX GLOBAL: RECURSÃO DE RLS EM TODAS AS TABELAS
-- v2.5.6 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Aplica a função SECURITY DEFINER get_my_academy_id()
-- em todas as tabelas de conteúdo para eliminar loops de RLS.
-- ============================================================

-- 1. DIETS (Dietas)
-- ------------------------------------------------------------
ALTER TABLE public.diets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Nutricionista pode ver dietas da academia" ON public.diets;
DROP POLICY IF EXISTS "Nutricionista pode criar dietas" ON public.diets;
DROP POLICY IF EXISTS "Nutricionista pode atualizar dietas da academia" ON public.diets;
DROP POLICY IF EXISTS "Nutricionista pode deletar dietas da academia" ON public.diets;
DROP POLICY IF EXISTS "Admin pode ver dietas da academia" ON public.diets;

CREATE POLICY "Nutri/Admin pode ver dietas da academia"
ON public.diets FOR SELECT USING ( id_academia = public.get_my_academy_id() );

CREATE POLICY "Nutri/Admin pode gerenciar dietas"
ON public.diets FOR ALL USING ( id_academia = public.get_my_academy_id() );


-- 2. WORKOUTS (Treinos)
-- ------------------------------------------------------------
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Personal pode ver treinos da academia" ON public.workouts;
DROP POLICY IF EXISTS "Personal pode criar treinos" ON public.workouts;
DROP POLICY IF EXISTS "Personal pode atualizar treinos da academia" ON public.workouts;
DROP POLICY IF EXISTS "Personal pode deletar treinos da academia" ON public.workouts;
DROP POLICY IF EXISTS "Admin pode ver treinos da academia" ON public.workouts;

CREATE POLICY "Personal/Admin pode ver treinos da academia"
ON public.workouts FOR SELECT USING ( id_academia = public.get_my_academy_id() );

CREATE POLICY "Personal/Admin pode gerenciar treinos"
ON public.workouts FOR ALL USING ( id_academia = public.get_my_academy_id() );


-- 3. PHYSICAL ASSESSMENTS (Avaliações Físicas)
-- ------------------------------------------------------------
ALTER TABLE public.physical_assessments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Profissionais podem ver avaliações da academia" ON public.physical_assessments;
DROP POLICY IF EXISTS "Admin pode ver avaliações da academia" ON public.physical_assessments;

CREATE POLICY "Profissionais/Admin pode ver avaliações da academia"
ON public.physical_assessments FOR SELECT USING ( id_academia = public.get_my_academy_id() );

CREATE POLICY "Profissionais/Admin pode gerenciar avaliações"
ON public.physical_assessments FOR ALL USING ( id_academia = public.get_my_academy_id() );


-- 4. NOTICES (Avisos)
-- ------------------------------------------------------------
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Todos podem ver avisos da academia" ON public.notices;
DROP POLICY IF EXISTS "Admin pode gerenciar avisos" ON public.notices;

CREATE POLICY "Membros/Admin podem ver avisos da academia"
ON public.notices FOR SELECT USING ( id_academia = public.get_my_academy_id() );

CREATE POLICY "Admin pode gerenciar avisos"
ON public.notices FOR ALL USING ( id_academia = auth.uid() );


-- 5. FINANCIAL TRANSACTIONS (Financeiro)
-- ------------------------------------------------------------
ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin pode ver transações da academia" ON public.financial_transactions;

CREATE POLICY "Admin pode ver transações da academia"
ON public.financial_transactions FOR SELECT USING ( id_academia = auth.uid() );

CREATE POLICY "Admin pode gerenciar transações"
ON public.financial_transactions FOR ALL USING ( id_academia = auth.uid() );


-- 6. RESETAR CACHE POSTGREST
-- ------------------------------------------------------------
NOTIFY pgrst, 'reload schema';

SELECT '✅ Todas as tabelas de conteúdo protegidas sem recursão!' as status;
