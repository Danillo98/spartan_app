-- ============================================================
-- TABULA RASA: LIMPEZA TOTAL DE RLS E RECRIAÇÃO VIA JWT
-- v2.8.0 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- O diagnóstico revelou a existência de dezenas de políticas
-- antigas de INSERT/UPDATE/DELETE e múltiplos SELECTs em 
-- notices e appointments que continham subqueries pesadas,
-- criando um laço recursivo que impedia o load do Schema.
-- ============================================================

-- 1. EXTIRPAÇÃO TOTAL DE POLÍTICAS EXISTENTES
-- ============================================================
-- Este bloco destrói dinamicamente 100% das políticas de todas 
-- as tabelas relacionadas a usuários e interações. Sem exceção.
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename IN (
            'users_adm', 'users_nutricionista', 'users_personal', 'users_alunos',
            'notices', 'appointments', 'diets', 'workouts', 
            'financial_transactions', 'physical_assessments'
        )
    )
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, 'public', r.tablename);
    END LOOP;
END $$;


-- 2. RECRIAR POLÍTICAS 100% BASEADAS EM JWT METADATA
-- ============================================================
-- Nenhum SELECT em outras tabelas será feito. O id_academia 
-- vem embutido no login (JWT) do usuário. É instantâneo e seguro.

-- A) TABELAS DE PERFIL
-- users_adm
CREATE POLICY "JWT_ADM_ALL" ON public.users_adm 
FOR ALL USING ( id = auth.uid() OR id::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- users_nutricionista
CREATE POLICY "JWT_NUTRI_ALL" ON public.users_nutricionista 
FOR ALL USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- users_personal
CREATE POLICY "JWT_PERSONAL_ALL" ON public.users_personal 
FOR ALL USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- users_alunos
CREATE POLICY "JWT_ALUNOS_ALL" ON public.users_alunos 
FOR ALL USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );


-- B) TABELAS DE CONTEÚDO (Todas agora usam id_academia que embutimos)
-- notices
CREATE POLICY "JWT_NOTICES_ALL" ON public.notices 
FOR ALL USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- appointments
CREATE POLICY "JWT_APPOINTMENTS_ALL" ON public.appointments 
FOR ALL USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- diets
CREATE POLICY "JWT_DIETS_ALL" ON public.diets 
FOR ALL USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- workouts
CREATE POLICY "JWT_WORKOUTS_ALL" ON public.workouts 
FOR ALL USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- physical_assessments
CREATE POLICY "JWT_ASSESSMENTS_ALL" ON public.physical_assessments 
FOR ALL USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );

-- financial_transactions
CREATE POLICY "JWT_FINANCIAL_ALL" ON public.financial_transactions 
FOR ALL USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );


-- 3. RECARGA FINAL DOS CACHES DO SUPABASE
-- ============================================================
NOTIFY pgrst, 'reload schema';

SELECT '✅ TABULA RASA APLICADA! O Sistema está limpo e 100% otimizado via JWT.' as status;
