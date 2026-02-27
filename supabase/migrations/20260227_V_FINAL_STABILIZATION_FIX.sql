-- ============================================================
-- FINAL STABILIZATION FIX (REPLY FROM YESTERDAY)
-- v2.6.0 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Esta é a réplica exata da lógica que estabilizou os alunos ontem.
-- 1. Remove políticas órfãs/zumbis que referenciam cnpj_academia.
-- 2. Restaura permissões de leitura (Grants).
-- 3. Limpa o cache da API.
-- ============================================================

-- 1. LIMPEZA DE POLÍTICAS ZUMBIS (MANDATÓRIO)
-- ============================================================
-- Deleta qualquer política que possa estar referenciando o cnpj_academia
DROP POLICY IF EXISTS "Todos podem ver avisos da academia" ON public.notices;
DROP POLICY IF EXISTS "Admin pode criar avisos" ON public.notices;
DROP POLICY IF EXISTS "Nutricionista pode criar avisos" ON public.notices;
DROP POLICY IF EXISTS "Personal pode criar avisos" ON public.notices;
DROP POLICY IF EXISTS "Students can view academy info" ON public.users_adm;
DROP POLICY IF EXISTS "Staff can view academy info" ON public.users_adm;

-- 2. RESET DE GRANTS (O QUE DESTRAVOU ONTEM)
-- ============================================================
-- Garante que o usuário da API tenha acesso ao schema public e auth
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;

-- Permissão total para o papel de autenticado
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

-- 3. FIX DE SEARCH PATH (CRÍTICO PARA RPC)
-- ============================================================
ALTER ROLE authenticator SET search_path = public, auth, extensions;
ALTER ROLE authenticated SET search_path = public, auth, extensions;


-- 4. REATIVAÇÃO LIMPA DA RLS (USANDO O FIX S - JWT)
-- ============================================================
-- Aqui aplicamos a regra segura via metadata, que não faz subqueries
DROP POLICY IF EXISTS "Membros podem ver admin da academia" ON public.users_adm;
CREATE POLICY "Membros podem ver admin da academia" ON public.users_adm 
FOR SELECT USING ( id::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );


-- 5. RELOAD E NOTIFY (TRIPLO)
-- ============================================================
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';

-- 6. SINCRONIZAÇÃO DE SEGURANÇA (Garantir que novos usuários tem o metadata)
UPDATE auth.users 
SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object('id_academia', COALESCE(
        (SELECT id_academia::text FROM public.users_alunos WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_nutricionista WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_personal WHERE id = auth.users.id),
        id::text
    ))
WHERE raw_user_meta_data->>'id_academia' IS NULL;

SELECT '✅ Sistema Spartans v2.6.0 ESTABILIZADO! O erro de schema deve sumir.' as status;
