-- ============================================================
-- THE YESTERDAY VACCINE: ESTABILIZAÇÃO TOTAL RLS/JWT
-- v2.6.7 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Esta é a réplica exata da solução de sucesso de ontem.
-- Ela elimina o "Database error querying schema" removendo
-- a recursão e usando o metadado do JWT para autenticação rápida.
-- ============================================================

-- 1. LIMPEZA DE POLÍTICAS CONFLITANTES
-- ============================================================
DROP POLICY IF EXISTS "RLS_JWT_ADM" ON public.users_adm;
DROP POLICY IF EXISTS "RLS_JWT_NUTRI" ON public.users_nutricionista;
DROP POLICY IF EXISTS "RLS_JWT_PERSONAL" ON public.users_personal;
DROP POLICY IF EXISTS "RLS_JWT_ALUNOS" ON public.users_alunos;
DROP POLICY IF EXISTS "RLS_ADM_SELECT" ON public.users_adm;
DROP POLICY IF EXISTS "RLS_NUTRI_SELECT" ON public.users_nutricionista;
DROP POLICY IF EXISTS "RLS_PERSONAL_SELECT" ON public.users_personal;
DROP POLICY IF EXISTS "RLS_ALUNOS_SELECT" ON public.users_alunos;

-- 2. SINCRONIZAÇÃO CRÍTICA DE METADADOS (O CORAÇÃO DA SOLUÇÃO)
-- ============================================================
-- Garante que o chip 'id_academia' esteja dentro do Token de todos os usuários.
-- Sem isso, o login trava tentando buscar a academia em outras tabelas.
UPDATE auth.users 
SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object('id_academia', COALESCE(
        (SELECT id_academia::text FROM public.users_alunos WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_nutricionista WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_personal WHERE id = auth.users.id),
        (SELECT id::text FROM public.users_adm WHERE id = auth.users.id)
    ))
WHERE (raw_user_meta_data->>'id_academia' IS NULL OR raw_user_meta_data->>'id_academia' = '');


-- 3. POLÍTICAS DE ACESSO DIRETO (JWT - SEM RECURSÃO)
-- ============================================================

-- USERS_ADM: O admin vê seu próprio registro e quem tem o seu ID como id_academia
CREATE POLICY "RLS_STABLE_ADM" ON public.users_adm FOR SELECT 
USING ( id = auth.uid() OR id::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- USERS_NUTRICIONISTA: Vê a si mesmo ou quem é da mesma academia
CREATE POLICY "RLS_STABLE_NUTRI" ON public.users_nutricionista FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- USERS_PERSONAL: Vê a si mesmo ou quem é da mesma academia
CREATE POLICY "RLS_STABLE_PERSONAL" ON public.users_personal FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- USERS_ALUNOS: Vê a si mesmo ou sua academia
CREATE POLICY "RLS_STABLE_ALUNOS" ON public.users_alunos FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );


-- 4. RECARGA E PERMISSÕES DE SISTEMA
-- ============================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;

-- Comando que "destrava" o schema na API
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';

SELECT '✅ VACINA DE ONTEM APLICADA! O login deve ser liberado agora.' as status;
