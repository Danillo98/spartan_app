-- ============================================================
-- 🚨 CIRURGIA ANTI-RECURSÃO (A SOLUÇÃO DEFINITIVA) 🚨
-- v3.1.0 - Spartan App 
-- ============================================================
-- Qual era o problema real?
-- A regra "Admin vê aluno" chamava a tabela users_adm.
-- A regra "Aluno vê admin" chamava a tabela users_alunos.
-- Isso criava um Loop Infinito no momento do login.
-- 
-- Qual o bloqueio aqui?
-- Criamos uma função de SECURITY DEFINER. Ela funciona
-- como um "Admin invisível" que lê o ID da academia sem
-- acionar nenhuma regra, cortando o Loop na RAIZ.
-- ============================================================

-- 1. CRIANDO A "VACINA" ANTI-LOOP (LEITURA BLINDADA)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_auth_academy_id()
RETURNS UUID
SECURITY DEFINER -- (Esta é a mágica que evita o Loop Infinite)
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_academy_id UUID;
    v_user_uuid UUID := auth.uid();
BEGIN
    IF v_user_uuid IS NULL THEN
        RETURN NULL;
    END IF;

    -- Tenta admin
    SELECT id INTO v_academy_id FROM users_adm WHERE id = v_user_uuid LIMIT 1;
    IF v_academy_id IS NOT NULL THEN RETURN v_academy_id; END IF;

    -- Tenta aluno
    SELECT id_academia INTO v_academy_id FROM users_alunos WHERE id = v_user_uuid LIMIT 1;
    IF v_academy_id IS NOT NULL THEN RETURN v_academy_id; END IF;
    
    -- Tenta nutricionista
    SELECT id_academia INTO v_academy_id FROM users_nutricionista WHERE id = v_user_uuid LIMIT 1;
    IF v_academy_id IS NOT NULL THEN RETURN v_academy_id; END IF;
    
    -- Tenta personal
    SELECT id_academia INTO v_academy_id FROM users_personal WHERE id = v_user_uuid LIMIT 1;
    
    RETURN v_academy_id;
END;
$$;


-- 2. CURANDO A TABELA DE ADMIN
-- ============================================================
-- Essa era a que aparecia no vermelho: "relation users_adm"
DROP POLICY IF EXISTS "Membros podem ver admin da academia" ON public.users_adm;
CREATE POLICY "Membros podem ver admin da academia" ON public.users_adm FOR SELECT USING (
  id = public.get_auth_academy_id()
);


-- 3. CURANDO A TABELA DE ALUNOS
-- ============================================================
-- Trocamos todas as subqueries geradoras de loop pela Função Blindada
DROP POLICY IF EXISTS "Admin pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Nutricionista pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Personal pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode criar alunos" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode atualizar alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode deletar alunos da academia" ON public.users_alunos;

CREATE POLICY "Staff_Select_Alunos_Fix" ON public.users_alunos FOR SELECT USING (id_academia = public.get_auth_academy_id());
CREATE POLICY "Staff_Update_Alunos_Fix" ON public.users_alunos FOR UPDATE USING (id_academia = public.get_auth_academy_id());
CREATE POLICY "Admin_Insert_Alunos_Fix" ON public.users_alunos FOR INSERT WITH CHECK (id_academia = public.get_auth_academy_id() OR auth.role() = 'service_role');
CREATE POLICY "Admin_Delete_Alunos_Fix" ON public.users_alunos FOR DELETE USING (id_academia = public.get_auth_academy_id());


-- 4. CURANDO A TABELA DE PERSONAIS
-- ============================================================
DO $$ 
DECLARE r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users_personal') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.users_personal', r.policyname);
    END LOOP;
END $$;

CREATE POLICY "Personal_Select_Proprio" ON public.users_personal FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Personal_Update_Proprio" ON public.users_personal FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Staff_Select_Personal_Fix" ON public.users_personal FOR SELECT USING (id_academia = public.get_auth_academy_id());
CREATE POLICY "Admin_Insert_Personal_Fix" ON public.users_personal FOR INSERT WITH CHECK (id_academia = public.get_auth_academy_id() OR auth.role() = 'service_role');
CREATE POLICY "Admin_Update_Personal_Fix" ON public.users_personal FOR UPDATE USING (id_academia = public.get_auth_academy_id());
CREATE POLICY "Admin_Delete_Personal_Fix" ON public.users_personal FOR DELETE USING (id_academia = public.get_auth_academy_id());


-- 5. CURANDO A TABELA DE NUTRICIONISTAS
-- ============================================================
DO $$ 
DECLARE r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users_nutricionista') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.users_nutricionista', r.policyname);
    END LOOP;
END $$;

CREATE POLICY "Nutri_Select_Proprio" ON public.users_nutricionista FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Nutri_Update_Proprio" ON public.users_nutricionista FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Staff_Select_Nutri_Fix" ON public.users_nutricionista FOR SELECT USING (id_academia = public.get_auth_academy_id());
CREATE POLICY "Admin_Insert_Nutri_Fix" ON public.users_nutricionista FOR INSERT WITH CHECK (id_academia = public.get_auth_academy_id() OR auth.role() = 'service_role');
CREATE POLICY "Admin_Update_Nutri_Fix" ON public.users_nutricionista FOR UPDATE USING (id_academia = public.get_auth_academy_id());
CREATE POLICY "Admin_Delete_Nutri_Fix" ON public.users_nutricionista FOR DELETE USING (id_academia = public.get_auth_academy_id());

-- 6. AVISAR O BANCO QUE TEMOS UMA NOVA ESTRATÉGIA
NOTIFY pgrst, 'reload schema';

SELECT '✅ OPERAÇÃO CIRÚRGICA DE RECURSÃO (SECURITY DEFINER) APLICADA COM SUCESSO.' as status;
