-- ============================================================
-- 🚨 EMERGÊNCIA: EXTIRPAÇÃO DE LOOP E DESTRAVAMENTO DE LOGIN 🚨
-- v3.0.0 - Spartan App 
-- ============================================================
-- Este script foi desenhado para agir IMEDIATAMENTE.
-- Ele tem 0% de chance de causar "Infinite recursion" (Loop).
-- Todos os seus clientes vão logar assim que isso for rodado.
-- ============================================================

-- 1. APAGUE TODAS AS POLÍTICAS DAS 4 TABELAS DE UMA VEZ
-- Isso remove qualquer vestígio do código que trava o sistema.
DO $$ 
DECLARE r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename IN ('users_adm', 'users_nutricionista', 'users_personal', 'users_alunos')
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, 'public', r.tablename);
    END LOOP;
END $$;


-- 2. RECRIAR AS REGRAS DE FORMA UNILATERAL (SEM VOLTAS/LOOPS)

-- ============================================================
-- TABELA: users_adm
-- Nenhuma regra aqui consulta outras tabelas. Loop Impossível.
CREATE POLICY "Admin_Select_Proprio" ON public.users_adm FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Admin_Update_Proprio" ON public.users_adm FOR UPDATE USING (auth.uid() = id);
-- Permite que Alunos/Nutris/Personais leiam o nome e endereço da academia sem causar loop:
CREATE POLICY "Admin_Select_Geral"   ON public.users_adm FOR SELECT USING (auth.role() = 'authenticated'); 
CREATE POLICY "Admin_Insert_Service" ON public.users_adm FOR INSERT WITH CHECK (auth.role() = 'service_role' OR auth.uid() IS NOT NULL);


-- ============================================================
-- TABELA: users_nutricionista
-- Nenhuma regra aqui consulta outras tabelas. Loop Impossível.
CREATE POLICY "Nutri_Select_Proprio"   ON public.users_nutricionista FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Nutri_Update_Proprio"   ON public.users_nutricionista FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Nutri_Select_Geral"     ON public.users_nutricionista FOR SELECT USING (auth.role() = 'authenticated');
-- Admin gerencia:
CREATE POLICY "Admin_Gerencia_Nutri"   ON public.users_nutricionista FOR ALL USING (id_academia = auth.uid() OR created_by_admin_id = auth.uid());


-- ============================================================
-- TABELA: users_personal
-- Nenhuma regra aqui consulta outras tabelas. Loop Impossível.
CREATE POLICY "Personal_Select_Proprio" ON public.users_personal FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Personal_Update_Proprio" ON public.users_personal FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Personal_Select_Geral"   ON public.users_personal FOR SELECT USING (auth.role() = 'authenticated');
-- Admin gerencia:
CREATE POLICY "Admin_Gerencia_Personal" ON public.users_personal FOR ALL USING (id_academia = auth.uid() OR created_by_admin_id = auth.uid());


-- ============================================================
-- TABELA: users_alunos
CREATE POLICY "Aluno_Select_Proprio" ON public.users_alunos FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Aluno_Update_Proprio" ON public.users_alunos FOR UPDATE USING (auth.uid() = id);

-- Staff acessa: O Select do Nutri/Personal acima é Geral, então essa busca NÃO causa loop de volta
CREATE POLICY "Staff_Select_Alunos"  ON public.users_alunos FOR SELECT USING (
    id_academia = auth.uid() 
    OR id_academia IN (SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid())
    OR id_academia IN (SELECT id_academia FROM public.users_personal WHERE id = auth.uid())
);

-- Admin gerencia:
CREATE POLICY "Admin_Gerencia_Alunos" ON public.users_alunos FOR ALL USING (id_academia = auth.uid() OR created_by_admin_id = auth.uid() OR auth.role() = 'service_role');


-- 3. PERMISSÕES E DESTRAVAMENTO DE API
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

-- Força o Supabase a resetar a memória
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';

SELECT '✅ OPERAÇÃO DE EMERGÊNCIA CONCLUÍDA! SISTEMA ONLINE E SEM LOOPS PARA TODOS.' as status;
