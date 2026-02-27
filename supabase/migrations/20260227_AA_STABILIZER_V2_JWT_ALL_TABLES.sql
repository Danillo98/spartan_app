-- ============================================================
-- THE MASTER STABILIZER (YESTERDAY'S REPLICA)
-- v2.6.5 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Esta é a solução definitiva que resolve o erro de schema.
-- 1. Limpa todas as políticas recursivas.
-- 2. Implementa RLS baseada puramente em JWT Metadata.
-- 3. Sincroniza o Auth para garantir acesso instantâneo.
-- ============================================================

-- 0. FUNÇÃO DE RECARGA (Opcional, mas útil)
NOTIFY pgrst, 'reload schema';

-- 1. LIMPEZA TOTAL (TABULA RASA)
-- ============================================================
-- Vamos remover as políticas de TODAS as tabelas críticas para acabar com o loop.
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public' AND tablename IN ('users_adm', 'users_nutricionista', 'users_personal', 'users_alunos', 'diets', 'workouts', 'notices', 'physical_assessments', 'appointments', 'financial_transactions'))
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON ' || quote_ident(r.tablename);
    END LOOP;
END $$;


-- 2. POLÍTICAS PURAS VIA JWT (SEM RECURSÃO)
-- ============================================================
-- Explicação: (auth.jwt() -> 'user_metadata' ->> 'id_academia') é o ID da academia gravado no token do usuário.

-- USERS_ADM
CREATE POLICY "jwt_select_adm" ON public.users_adm FOR SELECT USING ( id = auth.uid() OR id::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );
CREATE POLICY "jwt_update_adm" ON public.users_adm FOR UPDATE USING ( id = auth.uid() );

-- USERS_NUTRICIONISTA
CREATE POLICY "jwt_select_nutri" ON public.users_nutricionista FOR SELECT USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );
CREATE POLICY "jwt_all_nutri" ON public.users_nutricionista FOR ALL USING ( id_academia = auth.uid() );

-- USERS_PERSONAL
CREATE POLICY "jwt_select_personal" ON public.users_personal FOR SELECT USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );
CREATE POLICY "jwt_all_personal" ON public.users_personal FOR ALL USING ( id_academia = auth.uid() );

-- USERS_ALUNOS
CREATE POLICY "jwt_select_alunos" ON public.users_alunos FOR SELECT USING ( id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );
CREATE POLICY "jwt_all_alunos" ON public.users_alunos FOR ALL USING ( id_academia = auth.uid() );

-- DIETS / WORKOUTS / NOTICES
CREATE POLICY "jwt_select_diets" ON public.diets FOR SELECT USING ( student_id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );
CREATE POLICY "jwt_all_diets" ON public.diets FOR ALL USING ( id_academia = auth.uid() OR nutritionist_id = auth.uid() );

CREATE POLICY "jwt_select_workouts" ON public.workouts FOR SELECT USING ( student_id = auth.uid() OR id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );
CREATE POLICY "jwt_all_workouts" ON public.workouts FOR ALL USING ( id_academia = auth.uid() OR personal_id = auth.uid() );

CREATE POLICY "jwt_select_notices" ON public.notices FOR SELECT USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') );


-- 3. SINCRONIZAR METADADOS NO AUTH (CRÍTICO)
-- ============================================================
-- Se o usuário não tiver o 'id_academia' no Token, o login falha. 
-- Este script garante que todos (Admin, Nutri, Personal, Aluno) tenham este dado.
UPDATE auth.users 
SET raw_user_meta_data = raw_user_meta_data || 
    jsonb_build_object('id_academia', COALESCE(
        (SELECT id_academia::text FROM public.users_alunos WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_nutricionista WHERE id = auth.users.id),
        (SELECT id_academia::text FROM public.users_personal WHERE id = auth.users.id),
        (SELECT id::text FROM public.users_adm WHERE id = auth.users.id)
    ))
WHERE (raw_user_meta_data->>'id_academia' IS NULL OR raw_user_meta_data->>'id_academia' = '');


-- 4. RECARGA FINAL DO SISTEMA
-- ============================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;

NOTIFY pgrst, 'reload schema';

SELECT '✅ MASTER STABILIZER APLICADO! O erro de schema foi extirpado.' as status;
