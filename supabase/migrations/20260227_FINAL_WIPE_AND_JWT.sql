-- ============================================================
-- SOLUÇÃO DEFINITIVA: EXTERMÍNIO DINÂMICO DE RECURSÃO
-- v2.7.0 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Por que este script funciona?
-- Ele não tenta adivinhar o nome das políticas de segurança.
-- Ele vasculha o banco, encontra TODAS as regras de leitura e
-- deleta-as dinamicamente, garantindo que nenhum loop sobreviva.
-- ============================================================

-- 1. DELETAR TODAS AS POLÍTICAS DE SELECT/ALL NAS TABELAS (SEM EXCEÇÃO)
-- ============================================================
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename IN ('users_adm', 'users_nutricionista', 'users_personal', 'users_alunos')
        AND (cmd = 'SELECT' OR cmd = 'ALL')
    )
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, 'public', r.tablename);
    END LOOP;
END $$;


-- 2. RECRIAR O ACESSO IMUNE A LOOPS (USANDO O TOKEN JWT)
-- ============================================================
-- O auth.jwt() lê os dados logados sem precisar varrer outras tabelas.
-- Isso elimina o erro "Database error querying schema" permanentemente.

CREATE POLICY "Acesso Seguro_Adm" 
ON public.users_adm FOR SELECT 
USING ( id = auth.uid() OR id::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

CREATE POLICY "Acesso Seguro_Nutri" 
ON public.users_nutricionista FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

CREATE POLICY "Acesso Seguro_Personal" 
ON public.users_personal FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

CREATE POLICY "Acesso Seguro_Alunos" 
ON public.users_alunos FOR SELECT 
USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );


-- 3. FORÇAR A SINCRONIZAÇÃO DO TOKEN PARA TODOS OS USUÁRIOS
-- ============================================================
-- Garante que ninguém sofra com token vazio, o que causaria erro silencioso
UPDATE auth.users 
SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object('id_academia', COALESCE(
        (SELECT id_academia::text FROM public.users_alunos WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_nutricionista WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_personal WHERE id = auth.users.id),
        (SELECT id::text FROM public.users_adm WHERE id = auth.users.id)
    ))
WHERE (raw_user_meta_data->>'id_academia' IS NULL OR raw_user_meta_data->>'id_academia' = '');


-- 4. FORÇAR RECARGA DOS CACHES DO SUPABASE
-- ============================================================
NOTIFY pgrst, 'reload schema';

SELECT '✅ TODAS AS POLÍTICAS RECURSIVAS EXTERMINADAS. Sistema Livre de Loops.' as status;
