-- ============================================================
-- FIX DEFINITIVO: RLS VIA JWT (SEM RECURSÃO)
-- v2.5.7 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Resolve "Database error querying schema" eliminando subqueries
-- recursivas e usando o metadata do JWT do Supabase.
-- ============================================================

-- 1. LIMPEZA TOTAL DE FUNÇÕES PROBLEMÁTICAS
-- ============================================================
DROP FUNCTION IF EXISTS public.get_my_academy_id() CASCADE;


-- 2. GARANTIR QUE RLS ESTÁ ATIVADA (Reativando após o debug R)
-- ============================================================
ALTER TABLE public.users_adm ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_nutricionista ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_personal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_alunos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;


-- 3. POLÍTICAS DE TABELAS DE USUÁRIOS (JWT-BASED)
-- ============================================================

-- A) USERS_ADM
DROP POLICY IF EXISTS "Admin pode ver próprio registro" ON public.users_adm;
DROP POLICY IF EXISTS "Membros podem ver admin da academia" ON public.users_adm;
DROP POLICY IF EXISTS "Profissionais podem ver admin da academia" ON public.users_adm;
CREATE POLICY "Admin pode ver próprio registro" ON public.users_adm FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Membros podem ver admin da academia" ON public.users_adm FOR SELECT 
USING ( id::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- B) USERS_NUTRICIONISTA
DROP POLICY IF EXISTS "Nutricionista pode ver próprio perfil" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Nutricionistas podem ver próprio perfil" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Admin pode ver nutricionistas da academia" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Admin pode gerenciar nutricionistas" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Colegas podem ver nutricionistas" ON public.users_nutricionista;
CREATE POLICY "Nutricionista pode ver próprio perfil" ON public.users_nutricionista FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Admin pode gerenciar nutricionistas" ON public.users_nutricionista FOR ALL 
USING ( id_academia = auth.uid() );
CREATE POLICY "Colegas podem ver nutricionistas" ON public.users_nutricionista FOR SELECT 
USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- C) USERS_PERSONAL
DROP POLICY IF EXISTS "Personal pode ver próprio perfil" ON public.users_personal;
DROP POLICY IF EXISTS "Admin pode ver personals da academia" ON public.users_personal;
DROP POLICY IF EXISTS "Admin pode gerenciar personals" ON public.users_personal;
DROP POLICY IF EXISTS "Colegas podem ver personals" ON public.users_personal;
CREATE POLICY "Personal pode ver próprio perfil" ON public.users_personal FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Admin pode gerenciar personals" ON public.users_personal FOR ALL 
USING ( id_academia = auth.uid() );
CREATE POLICY "Colegas podem ver personals" ON public.users_personal FOR SELECT 
USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- D) USERS_ALUNOS
DROP POLICY IF EXISTS "Aluno pode ver próprio perfil" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Profissionais podem ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin gerencia alunos" ON public.users_alunos;
DROP POLICY IF EXISTS "Profissionais podem ver alunos" ON public.users_alunos;
CREATE POLICY "Aluno pode ver próprio perfil" ON public.users_alunos FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Admin gerencia alunos" ON public.users_alunos FOR ALL USING ( id_academia = auth.uid() );
CREATE POLICY "Profissionais podem ver alunos" ON public.users_alunos FOR SELECT 
USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );


-- 4. POLÍTICAS DE CONTEÚDO (DIETAS, TREINOS, ETC)
-- ============================================================

-- DIETS
DROP POLICY IF EXISTS "Nutri/Admin pode ver dietas da academia" ON public.diets;
DROP POLICY IF EXISTS "Nutri/Admin pode gerenciar dietas" ON public.diets;
DROP POLICY IF EXISTS "Acesso dietas academia" ON public.diets;
DROP POLICY IF EXISTS "Aluno vê própria dieta" ON public.diets;
CREATE POLICY "Acesso dietas academia" ON public.diets FOR ALL 
USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') OR id_academia = auth.uid() );
CREATE POLICY "Aluno vê própria dieta" ON public.diets FOR SELECT USING ( student_id = auth.uid() );

-- WORKOUTS
DROP POLICY IF EXISTS "Personal/Admin pode ver treinos da academia" ON public.workouts;
DROP POLICY IF EXISTS "Personal/Admin pode gerenciar treinos" ON public.workouts;
DROP POLICY IF EXISTS "Acesso treinos academia" ON public.workouts;
DROP POLICY IF EXISTS "Aluno vê próprio treino" ON public.workouts;
CREATE POLICY "Acesso treinos academia" ON public.workouts FOR ALL 
USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') OR id_academia = auth.uid() );
CREATE POLICY "Aluno vê próprio treino" ON public.workouts FOR SELECT USING ( student_id = auth.uid() );


-- 5. SINCRONIZAR METADATA DO AUTH (CRÍTICO)
-- ============================================================
-- Garante que o id_academia está no auth.users para que o JWT funcione
UPDATE auth.users 
SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object('id_academia', COALESCE(
        (SELECT id_academia::text FROM public.users_alunos WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_nutricionista WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_personal WHERE id = auth.users.id),
        id::text -- Se for admin, o ID dele é o ID da academia
    ))
WHERE raw_user_meta_data->>'id_academia' IS NULL;


-- 6. RESETAR CACHE
-- ============================================================
NOTIFY pgrst, 'reload schema';

SELECT '✅ Sistema estabilizado com RLS via JWT! Sem recursão, sem erro de schema.' as status;
