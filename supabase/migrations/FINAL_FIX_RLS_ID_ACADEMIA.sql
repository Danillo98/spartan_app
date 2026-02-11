-- ============================================
-- CORREÇÃO FINAL: POLÍTICAS RLS COM ID_ACADEMIA
-- ============================================
-- Este script remove TODAS as políticas antigas que usavam cnpj_academia
-- e recria usando id_academia

-- ============================================
-- 1. NOTICES - REMOVER POLÍTICAS ANTIGAS
-- ============================================
DROP POLICY IF EXISTS "Admins can manage notices" ON public.notices;
DROP POLICY IF EXISTS "Users can view notices from their academy" ON public.notices;
DROP POLICY IF EXISTS "Admin pode gerenciar avisos" ON public.notices;
DROP POLICY IF EXISTS "Usuarios podem ver avisos da academia" ON public.notices;

-- Recriar usando id_academia
CREATE POLICY "Admins can manage notices"
  ON public.notices
  FOR ALL
  USING (
    id_academia IN (
      SELECT id FROM public.users_adm 
      WHERE id = auth.uid()
    )
  );

CREATE POLICY "Users can view notices from their academy"
  ON public.notices
  FOR SELECT
  USING (
    -- Alunos
    (auth.uid() IN (SELECT id FROM public.users_alunos WHERE id_academia = notices.id_academia))
    OR
    -- Nutricionistas
    (auth.uid() IN (SELECT id FROM public.users_nutricionista WHERE id_academia = notices.id_academia))
    OR
    -- Personal Trainers
    (auth.uid() IN (SELECT id FROM public.users_personal WHERE id_academia = notices.id_academia))
    OR
    -- Admin
    (auth.uid() IN (SELECT id FROM public.users_adm WHERE id = notices.id_academia))
  );

-- ============================================
-- 2. APPOINTMENTS - REMOVER POLÍTICAS ANTIGAS
-- ============================================
DROP POLICY IF EXISTS "Admins can manage appointments" ON public.appointments;
DROP POLICY IF EXISTS "Users can view appointments" ON public.appointments;
DROP POLICY IF EXISTS "Nutri e Personal podem criar agendamentos" ON public.appointments;

-- Recriar usando id_academia  
CREATE POLICY "Admin pode gerenciar agendamentos"
  ON public.appointments
  FOR ALL
  USING (id_academia = auth.uid());

CREATE POLICY "Profissionais podem gerenciar agendamentos"
  ON public.appointments
  FOR ALL
  USING (
    id_academia IN (
      SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
      UNION
      SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
    )
  );

CREATE POLICY "Alunos podem ver seus agendamentos"
  ON public.appointments
  FOR SELECT
  USING (
    student_id = auth.uid()
  );

-- ============================================
-- 3. FINANCIAL_TRANSACTIONS - REMOVER POLÍTICAS ANTIGAS  
-- ============================================
DROP POLICY IF EXISTS "Admin pode ver transacoes" ON public.financial_transactions;
DROP POLICY IF EXISTS "Admin pode criar transacoes" ON public.financial_transactions;

CREATE POLICY "Admin pode gerenciar transacoes"
  ON public.financial_transactions
  FOR ALL
  USING (id_academia = auth.uid());

-- ============================================
-- VERIFICAÇÃO FINAL
-- ============================================
SELECT 'Políticas RLS corrigidas para usar id_academia!' AS status;
