-- ===============================================================
-- CORREÇÃO DE PERMISSÕES PARA AVALIAÇÕES FÍSICAS
-- ===============================================================

-- Remover policies antigas (que podiam estar quebradas ou usando cnpj)
DROP POLICY IF EXISTS "Nutritionists can view their academy assessments" ON public.physical_assessments;
DROP POLICY IF EXISTS "Nutritionists can insert assessments" ON public.physical_assessments;
DROP POLICY IF EXISTS "Nutritionists can update assessments" ON public.physical_assessments;
DROP POLICY IF EXISTS "Nutritionists can delete assessments" ON public.physical_assessments;

DROP POLICY IF EXISTS "Nutricionista pode ver avaliações da academia" ON public.physical_assessments;
DROP POLICY IF EXISTS "Nutricionista pode criar avaliações" ON public.physical_assessments;
DROP POLICY IF EXISTS "Nutricionista pode atualizar avaliações da academia" ON public.physical_assessments;
DROP POLICY IF EXISTS "Nutricionista pode deletar avaliações da academia" ON public.physical_assessments;

-- CRIAR NOVAS POLICIES (Baseadas em id_academia e nutritionist_id)

-- 1. VIEW (SELECT)
-- Nutricionista vê tudo da sua academia (ou pelo menos as que ele criou + alunos da academia)
CREATE POLICY "Nutricionista pode ver avaliações da academia" 
ON public.physical_assessments FOR SELECT 
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
  )
);

-- 2. CREATE (INSERT)
CREATE POLICY "Nutricionista pode criar avaliações" 
ON public.physical_assessments FOR INSERT 
WITH CHECK (
  id_academia IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
  )
  AND nutritionist_id = auth.uid()
);

-- 3. UPDATE
CREATE POLICY "Nutricionista pode atualizar avaliações da academia" 
ON public.physical_assessments FOR UPDATE 
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
  )
  AND nutritionist_id = auth.uid()
);

-- 4. DELETE
CREATE POLICY "Nutricionista pode deletar avaliações da academia" 
ON public.physical_assessments FOR DELETE 
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
  )
  AND nutritionist_id = auth.uid()
);

-- Permissões para Alunos (Ver suas próprias avaliações)
DROP POLICY IF EXISTS "Alunos podem ver suas avaliações" ON public.physical_assessments;
CREATE POLICY "Alunos podem ver suas avaliações" 
ON public.physical_assessments FOR SELECT 
USING (student_id = auth.uid());

SELECT 'Permissões de avaliação física corrigidas com sucesso!' as status;
