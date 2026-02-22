-- ===============================================================
-- CORREÇÃO DEFINITIVA DE RLS PARA AVALIAÇÕES FÍSICAS
-- Permite que Administradores, Nutricionistas e Personais salvem avaliações
-- ===============================================================

-- 1. Remover todas as políticas antigas para evitar conflitos
DROP POLICY IF EXISTS "Nutricionista pode ver avaliações da academia" ON public.physical_assessments;
DROP POLICY IF EXISTS "Nutricionista pode criar avaliações" ON public.physical_assessments;
DROP POLICY IF EXISTS "Nutricionista pode atualizar avaliações da academia" ON public.physical_assessments;
DROP POLICY IF EXISTS "Nutricionista pode deletar avaliações da academia" ON public.physical_assessments;
DROP POLICY IF EXISTS "Profissionais podem ver avaliações da academia" ON public.physical_assessments;
DROP POLICY IF EXISTS "Profissionais podem criar avaliações" ON public.physical_assessments;
DROP POLICY IF EXISTS "Profissionais podem atualizar avaliações" ON public.physical_assessments;
DROP POLICY IF EXISTS "Profissionais podem deletar avaliações" ON public.physical_assessments;
DROP POLICY IF EXISTS "Alunos podem ver suas avaliações" ON public.physical_assessments;

-- 2. Ajustar integridade referencial
-- O nutritionist_id deve apontar para auth.users para aceitar IDs de Admins e Personais também
ALTER TABLE public.physical_assessments 
DROP CONSTRAINT IF EXISTS physical_assessments_nutritionist_id_fkey;

ALTER TABLE public.physical_assessments 
ADD CONSTRAINT physical_assessments_nutritionist_id_fkey 
FOREIGN KEY (nutritionist_id) REFERENCES auth.users(id);

-- 3. Função auxiliar para pegar o ID da academia de qualquer profissional (Admin, Nutri ou Personal)
CREATE OR REPLACE FUNCTION get_professional_academy_id()
RETURNS UUID AS $$
DECLARE
  acad_id UUID;
BEGIN
  -- 1. Se for Admin, o ID dele é o ID da academia
  SELECT id INTO acad_id FROM public.users_adm WHERE id = auth.uid();
  IF acad_id IS NOT NULL THEN RETURN acad_id; END IF;

  -- 2. Se for Nutricionista
  SELECT id_academia INTO acad_id FROM public.users_nutricionista WHERE id = auth.uid();
  IF acad_id IS NOT NULL THEN RETURN acad_id; END IF;

  -- 3. Se for Personal
  SELECT id_academia INTO acad_id FROM public.users_personal WHERE id = auth.uid();
  IF acad_id IS NOT NULL THEN RETURN acad_id; END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Novas Políticas Unificadas

-- PERMISSÃO: Profissionais (Admin/Nutri/Personal)
-- SELECT
CREATE POLICY "Profissionais podem ver avaliações" 
ON public.physical_assessments FOR SELECT 
USING (
  id_academia = get_professional_academy_id()
);

-- INSERT
CREATE POLICY "Profissionais podem criar avaliações" 
ON public.physical_assessments FOR INSERT 
WITH CHECK (
  id_academia = get_professional_academy_id()
);

-- UPDATE
CREATE POLICY "Profissionais podem atualizar avaliações" 
ON public.physical_assessments FOR UPDATE 
USING (
  id_academia = get_professional_academy_id()
);

-- DELETE
CREATE POLICY "Profissionais podem deletar avaliações" 
ON public.physical_assessments FOR DELETE 
USING (
  id_academia = get_professional_academy_id()
);

-- PERMISSÃO: Alunos (Ver apenas as suas)
CREATE POLICY "Alunos podem ver suas próprias avaliações" 
ON public.physical_assessments FOR SELECT 
USING (student_id = auth.uid());

-- 5. Atualizar políticas de UPDATE em users_alunos
-- Para permitir que Nutricionistas e Personais atualizem a data de nascimento
DROP POLICY IF EXISTS "Admin pode atualizar alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Profissionais podem atualizar alunos da academia" ON public.users_alunos;

CREATE POLICY "Profissionais podem atualizar alunos da academia" 
ON public.users_alunos FOR UPDATE 
USING (
  id_academia = get_professional_academy_id()
);

-- 6. Habilitar RLS (garantia)
ALTER TABLE public.physical_assessments ENABLE ROW LEVEL SECURITY;

SELECT '✅ Correção de RLS para physical_assessments e users_alunos aplicada!' as status;
