-- CORREÇÃO DE POLÍTICAS RLS
-- Problema: Políticas tentam buscar cnpj_academia de users_adm, mas a tabela tem apenas 'cnpj'

-- ============================================
-- 1. CORRIGIR POLICIES DA TABELA NOTICES
-- ============================================

-- Drop policies antigas
DROP POLICY IF EXISTS "Admins can manage notices" ON public.notices;
DROP POLICY IF EXISTS "Users can view notices from their academy" ON public.notices;

-- Recriar policies com a coluna correta
CREATE POLICY "Admins can manage notices"
  ON public.notices
  FOR ALL
  USING (
    cnpj_academia IN (
      SELECT cnpj FROM public.users_adm 
      WHERE id = auth.uid()
    )
  );

CREATE POLICY "Users can view notices from their academy"
  ON public.notices
  FOR SELECT
  USING (
    (auth.uid() IN (SELECT id FROM public.users_alunos WHERE cnpj_academia = notices.cnpj_academia))
    OR
    (auth.uid() IN (SELECT id FROM public.users_nutricionista WHERE cnpj_academia = notices.cnpj_academia))
    OR
    (auth.uid() IN (SELECT id FROM public.users_personal WHERE cnpj_academia = notices.cnpj_academia))
    OR
    (auth.uid() IN (SELECT id FROM public.users_adm WHERE cnpj = notices.cnpj_academia))
  );

-- ============================================
-- 2. CORRIGIR POLICIES DA TABELA APPOINTMENTS
-- ============================================

-- Verificar e corrigir appointments
DROP POLICY IF EXISTS "Admins can manage appointments" ON public.appointments;

CREATE POLICY "Admins can manage appointments"
  ON public.appointments
  FOR ALL
  USING (cnpj_academia = (SELECT cnpj FROM users_adm WHERE id = auth.uid()))
  WITH CHECK (cnpj_academia = (SELECT cnpj FROM users_adm WHERE id = auth.uid()));

-- ============================================
-- 3. VERIFICAÇÃO FINAL
-- ============================================
SELECT 'Políticas RLS corrigidas com sucesso!' AS status;
