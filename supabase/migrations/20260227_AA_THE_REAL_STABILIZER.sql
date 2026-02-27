-- ============================================================
-- THE REAL STABILIZER: JWT-BASED SECURITY (YESTERDAY'S FIX)
-- v2.6.5 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Este script replica a solução exata que funcionou ontem.
-- Ele elimina toda recursão usando metadados do JWT.
-- ============================================================

-- 1. LIMPEZA RADICAL DE POLÍTICAS RECURSIVAS
-- ============================================================
DROP POLICY IF EXISTS "Admin pode ver próprio registro" ON public.users_adm;
DROP POLICY IF EXISTS "Membros vêem admin" ON public.users_adm;
DROP POLICY IF EXISTS "Membros podem ver admin da academia" ON public.users_adm;
DROP POLICY IF EXISTS "Admin pode ver próprio perfil" ON public.users_adm;
DROP POLICY IF EXISTS "RLS_ADM_SELECT" ON public.users_adm;

DROP POLICY IF EXISTS "Nutricionista vê próprio perfil" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Admin vê seus nutricionistas" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Admin gerencia seus nutricionistas" ON public.users_nutricionista;
DROP POLICY IF EXISTS "RLS_NUTRI_SELECT" ON public.users_nutricionista;

DROP POLICY IF EXISTS "Personal vê próprio perfil" ON public.users_personal;
DROP POLICY IF EXISTS "Admin vê seus personals" ON public.users_personal;
DROP POLICY IF EXISTS "Admin gerencia seus personals" ON public.users_personal;
DROP POLICY IF EXISTS "RLS_PERSONAL_SELECT" ON public.users_personal;

DROP POLICY IF EXISTS "Aluno vê próprio perfil" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin vê seus alunos" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin gerencia seus alunos" ON public.users_alunos;
DROP POLICY IF EXISTS "Nutri vê alunos" ON public.users_alunos;
DROP POLICY IF EXISTS "Personal vê alunos" ON public.users_alunos;
DROP POLICY IF EXISTS "RLS_ALUNOS_SELECT" ON public.users_alunos;


-- 2. APLICAÇÃO DE POLÍTICAS VIA JWT (SEGURO E RÁPIDO)
-- ============================================================
-- Não fazemos SELECT em outras tabelas. Lemos o metadado do token.

-- USERS_ADM
CREATE POLICY "RLS_ADM_SELECT" ON public.users_adm FOR SELECT 
USING ( id = auth.uid() OR id::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- USERS_NUTRICIONISTA
CREATE POLICY "RLS_NUTRI_SELECT" ON public.users_nutricionista FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- USERS_PERSONAL
CREATE POLICY "RLS_PERSONAL_SELECT" ON public.users_personal FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- USERS_ALUNOS
CREATE POLICY "RLS_ALUNOS_SELECT" ON public.users_alunos FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );


-- 3. PERMISSÕES DE SISTEMA (GRANTS)
-- ============================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;


-- 4. SINCRONIZAÇÃO DE METADADOS (O QUE SALVOU ONTÉM)
-- ============================================================
-- Este comando garante que todos os usuários tenham o ID da academia no chip de login.
UPDATE auth.users 
SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object('id_academia', COALESCE(
        (SELECT id_academia::text FROM public.users_alunos WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_nutricionista WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_personal WHERE id = auth.users.id),
        id::text 
    ))
WHERE raw_user_meta_data->>'id_academia' IS NULL 
   OR raw_user_meta_data->>'id_academia' = '';


-- 5. RECARGA DO SCHEMA (NOTIFY)
-- ============================================================
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';

SELECT '🚀 ESTABILIZADOR AA APLICADO! O login deve funcionar agora.' as status;
