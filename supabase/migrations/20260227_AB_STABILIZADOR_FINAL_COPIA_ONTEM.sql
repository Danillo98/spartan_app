-- ============================================================
-- THE YESTERDAY REPLICA: STABILIZADOR FINAL
-- v2.6.6 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Esta é a cópia fiel da solução que estabilizou os alunos ontem.
-- Ela resolve o erro de "Database error querying schema" 
-- restaurando a integridade dos privilégios e do cache da API.
-- ============================================================

-- 1. RESTAURAÇÃO DE PRIVILÉGIOS (MANDATÓRIO)
-- ============================================================
-- Garante que o PostgREST (API) consiga ler as tabelas sem erro de permissão
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

-- 2. LIMPEZA TOTAL DE POLÍTICAS ZUMBIS
-- ============================================================
-- Deleta todas as políticas das tabelas de login para zerar a recursão
DROP POLICY IF EXISTS "RLS_ADM_SELECT" ON public.users_adm;
DROP POLICY IF EXISTS "RLS_NUTRI_SELECT" ON public.users_nutricionista;
DROP POLICY IF EXISTS "RLS_PERSONAL_SELECT" ON public.users_personal;
DROP POLICY IF EXISTS "RLS_ALUNOS_SELECT" ON public.users_alunos;

-- 3. APLICAÇÃO DA REGRA DE SEGURANÇA VIA JWT (ONTEM)
-- ============================================================
-- Aqui usamos o id_academia vindo do Token (auth.jwt()), que não causa loop.

CREATE POLICY "RLS_JWT_ADM" ON public.users_adm FOR SELECT 
USING ( id = auth.uid() OR id::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

CREATE POLICY "RLS_JWT_NUTRI" ON public.users_nutricionista FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

CREATE POLICY "RLS_JWT_PERSONAL" ON public.users_personal FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

CREATE POLICY "RLS_JWT_ALUNOS" ON public.users_alunos FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );


-- 4. SINCRONIZAÇÃO DE IDENTIDADE NO AUTH (O SEGREDO)
-- ============================================================
-- Este comando garante que todos os usuários tenham o chip 'id_academia' no login.
UPDATE auth.users 
SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object('id_academia', COALESCE(
        (SELECT id_academia::text FROM public.users_alunos WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_nutricionista WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_personal WHERE id = auth.users.id),
        id::text -- Fallback para o próprio ID se for admin
    ))
WHERE (raw_user_meta_data->>'id_academia' IS NULL OR raw_user_meta_data->>'id_academia' = '');


-- 5. RELOAD E LIMPEZA DE CACHE
-- ============================================================
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';

SELECT '✅ ESTABILIZADOR AB APLICADO! Use o login agora.' as status;
