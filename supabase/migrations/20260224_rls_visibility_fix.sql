-- 1. FUNÇÕES AUXILIARES SEGURAS (Security Definer ignora RLS interno)
CREATE OR REPLACE FUNCTION public.check_user_academia(p_academia_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users_alunos WHERE id = auth.uid() AND id_academia = p_academia_id
    UNION ALL
    SELECT 1 FROM public.users_nutricionista WHERE id = auth.uid() AND id_academia = p_academia_id
    UNION ALL
    SELECT 1 FROM public.users_personal WHERE id = auth.uid() AND id_academia = p_academia_id
    UNION ALL
    SELECT 1 FROM public.users_adm WHERE id = auth.uid() AND id = p_academia_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. LIMPEZA TOTAL das políticas problemáticas
DROP POLICY IF EXISTS "Students can view academy info" ON public.users_adm;
DROP POLICY IF EXISTS "Admin pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Nutricionista pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Personal pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Students can view nutritionist names in their academy" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Students can view personal names in their academy" ON public.users_personal;
DROP POLICY IF EXISTS "Staff can view academy info" ON public.users_adm;
DROP POLICY IF EXISTS "Admins can view their own data" ON public.users_adm;

-- 3. POLÍTICAS PARA USERS_ADM (Academia)
-- Admin vê a si mesmo
CREATE POLICY "Admins can view their own data" 
ON public.users_adm FOR SELECT 
USING (id = auth.uid());

-- Alunos/Staff vêem a academia
CREATE POLICY "All members can view academy info" 
ON public.users_adm FOR SELECT 
USING (public.check_user_academia(id));

-- 4. POLÍTICAS PARA USERS_ALUNOS
-- Admin vê alunos
CREATE POLICY "Admin pode ver alunos da academia" 
ON public.users_alunos FOR SELECT 
USING (id_academia = auth.uid());

-- Nutri/Personal vê alunos
CREATE POLICY "Staff pode ver alunos da academia" 
ON public.users_alunos FOR SELECT 
USING (public.check_user_academia(id_academia));

-- Aluno vê a si mesmo
DROP POLICY IF EXISTS "Aluno pode ver próprio perfil" ON public.users_alunos;
CREATE POLICY "Aluno pode ver próprio perfil" 
ON public.users_alunos FOR SELECT 
USING (auth.uid() = id);

-- 5. POLÍTICAS PARA PROFISSIONAIS
-- Visibilidade para Alunos e Colegas
CREATE POLICY "All members can view nutritionist names"
ON public.users_nutricionista FOR SELECT
USING (public.check_user_academia(id_academia));

CREATE POLICY "All members can view personal names"
ON public.users_personal FOR SELECT
USING (public.check_user_academia(id_academia));

SELECT '✅ Recursão de RLS corrigida via Security Definer!' as status;
