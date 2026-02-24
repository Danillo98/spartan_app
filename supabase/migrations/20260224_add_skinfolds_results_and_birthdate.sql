-- Migration para adicionar resultados de dobras e data de nascimento na avaliação
-- Data: 2026-02-24

ALTER TABLE public.physical_assessments 
ADD COLUMN IF NOT EXISTS gender TEXT DEFAULT 'M',
ADD COLUMN IF NOT EXISTS body_fat_3_folds NUMERIC,
ADD COLUMN IF NOT EXISTS body_fat_7_folds NUMERIC,
ADD COLUMN IF NOT EXISTS student_birth_date DATE;

-- Garantir que a política de select para o aluno existe e está correta
DROP POLICY IF EXISTS "Students can view their own assessments" ON public.physical_assessments;
CREATE POLICY "Students can view their own assessments"
ON public.physical_assessments FOR SELECT
USING (student_id = auth.uid());

-- Garantir que a política de select para o admin e o staff também considere a academia
-- O Admin é o dono da academia (id_academia = auth.uid())
DROP POLICY IF EXISTS "Admins can view all academy assessments" ON public.physical_assessments;
CREATE POLICY "Admins can view all academy assessments"
ON public.physical_assessments FOR ALL
USING (id_academia = auth.uid());

-- Garantir que Staff (Nutri/Personal) possa ver e criar na sua academia
DROP POLICY IF EXISTS "Staff can manage assessments in their academy" ON public.physical_assessments;
CREATE POLICY "Staff can manage assessments in their academy"
ON public.physical_assessments FOR ALL
USING (
  nutritionist_id = auth.uid() OR 
  personal_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM public.users_nutricionista WHERE id = auth.uid() AND id_academia = physical_assessments.id_academia
  ) OR
  EXISTS (
    SELECT 1 FROM public.users_personal WHERE id = auth.uid() AND id_academia = physical_assessments.id_academia
  )
);
