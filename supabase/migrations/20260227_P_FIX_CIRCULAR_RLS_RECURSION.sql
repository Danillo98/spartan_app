-- ============================================================
-- FIX DEFINITIVO: CIRCULAR RLS RECURSION
-- v2.5.6 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Este script resolve o erro "Database error querying schema"
-- causado por políticas de RLS circulares (Recursion).
-- Ex: Admin vê Nutri -> Nutri policy checa Admin -> Ciclo infinito.
-- ============================================================

-- 1. CRIAR FUNÇÃO AUXILIAR (SECURITY DEFINER)
-- Bypassa RLS para buscar o ID da academia sem recursão
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_academy_id()
RETURNS UUID AS $$
DECLARE
    v_id_academia UUID;
BEGIN
    -- 1. Tentar Admin (o próprio ID é o ID da academia)
    SELECT id INTO v_id_academia FROM public.users_adm WHERE id = auth.uid();
    IF v_id_academia IS NOT NULL THEN RETURN v_id_academia; END IF;

    -- 2. Tentar Nutricionista
    SELECT id_academia INTO v_id_academia FROM public.users_nutricionista WHERE id = auth.uid();
    IF v_id_academia IS NOT NULL THEN RETURN v_id_academia; END IF;

    -- 3. Tentar Personal 
    SELECT id_academia INTO v_id_academia FROM public.users_personal WHERE id = auth.uid();
    IF v_id_academia IS NOT NULL THEN RETURN v_id_academia; END IF;

    -- 4. Tentar Aluno
    SELECT id_academia INTO v_id_academia FROM public.users_alunos WHERE id = auth.uid();
    RETURN v_id_academia;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. LIMPAR E RECRIAR TOTALMENTE AS POLÍTICAS (SEM RECURSÃO)
-- ============================================================

-- A) USERS_ADM
-- ------------------------------------------------------------
ALTER TABLE public.users_adm ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin pode ver próprio registro" ON public.users_adm;
DROP POLICY IF EXISTS "Membros podem ver admin da academia" ON public.users_adm;
DROP POLICY IF EXISTS "Profissionais podem ver admin da academia" ON public.users_adm;

CREATE POLICY "Admin pode ver próprio registro"
ON public.users_adm FOR SELECT USING (auth.uid() = id);

-- Usa a função SECURITY DEFINER para evitar recursion
CREATE POLICY "Membros podem ver admin da academia"
ON public.users_adm FOR SELECT 
USING ( id = public.get_my_academy_id() );


-- B) USERS_NUTRICIONISTA
-- ------------------------------------------------------------
ALTER TABLE public.users_nutricionista ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Nutricionista pode ver próprio perfil" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Nutricionistas podem ver próprio perfil" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Admin pode ver nutricionistas da academia" ON public.users_nutricionista;

CREATE POLICY "Nutricionista pode ver próprio perfil"
ON public.users_nutricionista FOR SELECT USING (auth.uid() = id);

-- Simplificado: Se eu sou o Admin desta id_academia, posso ver. (Sem subquery circular)
CREATE POLICY "Admin pode ver nutricionistas da academia"
ON public.users_nutricionista FOR SELECT 
USING ( id_academia = auth.uid() );

CREATE POLICY "Admin pode gerenciar nutricionistas"
ON public.users_nutricionista FOR ALL
USING ( id_academia = auth.uid() );


-- C) USERS_PERSONAL
-- ------------------------------------------------------------
ALTER TABLE public.users_personal ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Personal pode ver próprio perfil" ON public.users_personal;
DROP POLICY IF EXISTS "Admin pode ver personals da academia" ON public.users_personal;

CREATE POLICY "Personal pode ver próprio perfil"
ON public.users_personal FOR SELECT USING (auth.uid() = id);

-- Simplificado: Se eu sou o Admin desta id_academia, posso ver. (Sem subquery circular)
CREATE POLICY "Admin pode ver personals da academia"
ON public.users_personal FOR SELECT 
USING ( id_academia = auth.uid() );

CREATE POLICY "Admin pode gerenciar personals"
ON public.users_personal FOR ALL
USING ( id_academia = auth.uid() );


-- D) USERS_ALUNOS
-- ------------------------------------------------------------
ALTER TABLE public.users_alunos ENABLE ROW LEVEL SECURITY;
-- Remove todas as políticas antigas para garantir limpeza
DROP POLICY IF EXISTS "Aluno pode ver próprio perfil" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Nutricionista pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Personal pode ver alunos da academia" ON public.users_alunos;

CREATE POLICY "Aluno pode ver próprio perfil"
ON public.users_alunos FOR SELECT USING (auth.uid() = id);

-- Admin da academia vê se o ID da academia for o dele
CREATE POLICY "Admin pode ver alunos da academia"
ON public.users_alunos FOR SELECT USING ( id_academia = auth.uid() );

-- Outros profissionais vêem via função de academia (Não circular)
CREATE POLICY "Profissionais podem ver alunos da academia"
ON public.users_alunos FOR SELECT 
USING ( id_academia = public.get_my_academy_id() );

-- Permissões de escrita do Admin (Simples)
CREATE POLICY "Admin gerencia alunos"
ON public.users_alunos FOR ALL
USING ( id_academia = auth.uid() );


-- 3. RESETAR CACHE POSTGREST
-- ============================================================
NOTIFY pgrst, 'reload schema';

SELECT '✅ Recursão de RLS Resolvida! O erro de schema deve desaparecer agora.' as status;
