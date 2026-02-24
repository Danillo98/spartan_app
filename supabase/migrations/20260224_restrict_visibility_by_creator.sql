-- ====================================================================
-- MIGRAÇÃO: RESTRIÇÃO DE VISIBILIDADE PARA STAFF E ACESSO TOTAL ADMIN
-- ====================================================================
-- Descrição: 
-- 1. Garante que funcionários vejam apenas o conteúdo criado por eles.
-- 2. Administradores continuam vendo tudo da sua academia.
-- 3. Alunos continuam vendo apenas o seu próprio conteúdo.

-- ====================================================================
-- 1. TABELA: DIETS
-- ====================================================================

ALTER TABLE public.diets ENABLE ROW LEVEL SECURITY;

-- Limpar políticas antigas
DROP POLICY IF EXISTS "Nutricionista pode ver dietas da academia" ON public.diets;
DROP POLICY IF EXISTS "Nutricionista pode criar dietas" ON public.diets;
DROP POLICY IF EXISTS "Nutricionista pode atualizar dietas da academia" ON public.diets;
DROP POLICY IF EXISTS "Nutricionista pode deletar dietas da academia" ON public.diets;
DROP POLICY IF EXISTS "Aluno pode ver próprias dietas" ON public.diets;
DROP POLICY IF EXISTS "Admins can view all academy diets" ON public.diets;

-- A) ADMIN: Vê tudo, cria, edita e deleta na sua academia
CREATE POLICY "Admin gerencia todas as dietas da academia"
ON public.diets FOR ALL
USING (id_academia = auth.uid())
WITH CHECK (id_academia = auth.uid());

-- B) STAFF (NUTRI): Vê, cria, edita e deleta APENAS o que criou
CREATE POLICY "Staff gerencia apenas suas próprias dietas"
ON public.diets FOR ALL
USING (nutritionist_id = auth.uid())
WITH CHECK (nutritionist_id = auth.uid());

-- C) ALUNO: Vê apenas suas próprias dietas
CREATE POLICY "Aluno vê apenas suas próprias dietas"
ON public.diets FOR SELECT
USING (student_id = auth.uid());


-- ====================================================================
-- 2. TABELA: WORKOUTS (FICHAS DE TREINO)
-- ====================================================================

ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;

-- Limpar políticas antigas
DROP POLICY IF EXISTS "Personal pode ver treinos da academia" ON public.workouts;
DROP POLICY IF EXISTS "Personal pode criar treinos" ON public.workouts;
DROP POLICY IF EXISTS "Personal pode atualizar treinos da academia" ON public.workouts;
DROP POLICY IF EXISTS "Personal pode deletar treinos da academia" ON public.workouts;
DROP POLICY IF EXISTS "Aluno pode ver próprios treinos" ON public.workouts;
DROP POLICY IF EXISTS "Personal can update own workouts" ON public.workouts;
DROP POLICY IF EXISTS "Personal can delete own workouts" ON public.workouts;

-- A) ADMIN: Vê tudo, cria, edita e deleta na sua academia
CREATE POLICY "Admin gerencia todos os treinos da academia"
ON public.workouts FOR ALL
USING (id_academia = auth.uid())
WITH CHECK (id_academia = auth.uid());

-- B) STAFF (PERSONAL): Vê, cria, edita e deleta APENAS o que criou
CREATE POLICY "Staff gerencia apenas seus próprios treinos"
ON public.workouts FOR ALL
USING (personal_id = auth.uid())
WITH CHECK (personal_id = auth.uid());

-- C) ALUNO: Vê apenas seus próprios treinos
CREATE POLICY "Aluno vê apenas seus próprios treinos"
ON public.workouts FOR SELECT
USING (student_id = auth.uid());


-- ====================================================================
-- 3. TABELA: PHYSICAL_ASSESSMENTS (AVALIAÇÕES FÍSICAS)
-- ====================================================================

ALTER TABLE public.physical_assessments ENABLE ROW LEVEL SECURITY;

-- Limpar políticas antigas
DROP POLICY IF EXISTS "Admins can view all academy assessments" ON public.physical_assessments;
DROP POLICY IF EXISTS "Staff can view their own assessments" ON public.physical_assessments;
DROP POLICY IF EXISTS "Students can view their own assessments" ON public.physical_assessments;
DROP POLICY IF EXISTS "Staff can insert their own assessments" ON public.physical_assessments;
DROP POLICY IF EXISTS "Owners can update assessments" ON public.physical_assessments;
DROP POLICY IF EXISTS "Owners can delete assessments" ON public.physical_assessments;

-- A) ADMIN: Vê tudo, cria, edita e deleta na sua academia
CREATE POLICY "Admin gerencia todas as avaliações da academia"
ON public.physical_assessments FOR ALL
USING (id_academia = auth.uid())
WITH CHECK (id_academia = auth.uid());

-- B) STAFF: Vê, cria, edita e deleta APENAS o que criou
-- Nota: nutritionist_id é usado para qualquer profissional que criou a avaliação
CREATE POLICY "Staff gerencia apenas suas próprias avaliações"
ON public.physical_assessments FOR ALL
USING (nutritionist_id = auth.uid())
WITH CHECK (nutritionist_id = auth.uid());

-- C) ALUNO: Vê apenas suas próprias avaliações
CREATE POLICY "Aluno vê apenas suas próprias avaliações"
ON public.physical_assessments FOR SELECT
USING (student_id = auth.uid());

-- MENSAGEM DE SUCESSO
SELECT '✅ Restrição de visibilidade por criador aplicada com sucesso!' as status;
