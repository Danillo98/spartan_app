-- Migration para corrigir a recursão infinita no RLS e restaurar o login do Administrador
-- Data: 2026-02-24

-- 1. LIMPEZA TOTAL das políticas problemáticas que causam loop entre users_adm e users_alunos
DROP POLICY IF EXISTS "Students can view academy info" ON public.users_adm;
DROP POLICY IF EXISTS "Admin pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Students can view nutritionist names in their academy" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Students can view personal names in their academy" ON public.users_personal;

-- 2. GARANTIR QUE ADMIN PODE LOGAR (Ver seu próprio registro em users_adm)
-- Esta política é fundamental e deve ser a primeira.
DROP POLICY IF EXISTS "Admins can view their own data" ON public.users_adm;
CREATE POLICY "Admins can view their own data" 
ON public.users_adm FOR SELECT 
USING (auth.uid() = id);

-- 3. VISIBILIDADE DA ACADEMIA PARA ALUNOS (Sem Recursão)
-- Permitimos que o aluno veja os dados básicos da academia (users_adm) se o id_academia bater.
-- Importante: A política abaixo NÃO deve disparar RLS recursivo em users_alunos se possível.
CREATE POLICY "Students can view academy info" 
ON public.users_adm FOR SELECT 
USING (
  id IN (
    SELECT id_academia FROM public.users_alunos WHERE id = auth.uid()
  )
);

-- 4. VISIBILIDADE DE ALUNOS PARA ADMIN (Sem Recursão)
-- Mudamos: em vez de fazer join com users_adm (que tem RLS), usamos apenas o check do UUID.
-- Isso quebra o ciclo vicioso.
DROP POLICY IF EXISTS "Admin pode ver alunos da academia" ON public.users_alunos;
CREATE POLICY "Admin pode ver alunos da academia" 
ON public.users_alunos FOR SELECT 
USING (id_academia = auth.uid());

-- 5. VISIBILIDADE DE PROFISSIONAIS PARA ALUNOS
-- Nutricionistas
CREATE POLICY "Students can view nutritionist names in their academy"
ON public.users_nutricionista FOR SELECT
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_alunos WHERE id = auth.uid()
  )
);

-- Personal Trainers
CREATE POLICY "Students can view personal names in their academy"
ON public.users_personal FOR SELECT
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_alunos WHERE id = auth.uid()
  )
);

-- 6. Garantir que Nutricionistas e Personais também podem ver os dados da academia
DROP POLICY IF EXISTS "Staff can view academy info" ON public.users_adm;
CREATE POLICY "Staff can view academy info"
ON public.users_adm FOR SELECT
USING (
  id IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
    UNION
    SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
  )
);

SELECT '✅ Recursão de RLS corrigida e login de Admin restaurado!' as status;
