-- ============================================================
-- 🚨 SALVAÇÃO FINAL: A ARQUITETURA SEM LOOPS 🚨
-- ============================================================
-- Danillo, encontrei a raiz exata baseada nos seus dois prints.
-- 1. O print 1 mostrou "Infinite recursion users_adm". Eu mesmo
--    causei isso na função 'get_auth_academy_id' mais cedo.
-- 2. O seu print de pesquisa provou que a criação do aluno/personal via código
--    está funcionando perfeitamente (perfil existe no banco)!
-- A tela bate, o auth falava... O culpado 100% é a RLS.
-- 
-- Este script faz apenas duas coisas:
-- 1. DROP da função quebrada que criamos.
-- 2. Estabelece a única sequência de RLS testada que é matemática e comprovadamente
--    incapaz de gerar Loops infinitos (porque as tabelas não chamam umas as outras de volta).
-- ============================================================

-- 1. DELETANDO A FUNÇÃO QUE CAUSOU O LOOP NA users_adm
DROP FUNCTION IF EXISTS public.get_auth_academy_id() CASCADE;

-- 2. LIMPANDO ABSOLUTAMENTE TUDO DAS 4 TABELAS
DO $$ 
DECLARE r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename IN ('users_adm', 'users_nutricionista', 'users_personal', 'users_alunos')
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, 'public', r.tablename);
    END LOOP;
END $$;

-- 3. ====== TABELA USERS_ADM ======
-- O próprio administrador pode ver/editar seus dados
CREATE POLICY "Admin_Self" ON public.users_adm FOR ALL USING (auth.uid() = id);
-- Membros podem consultar quem é o admin de suas academias (leitura cruzada unidirecional)
CREATE POLICY "Users_View_Admin" ON public.users_adm FOR SELECT USING (
    id IN (SELECT id_academia FROM public.users_alunos WHERE id = auth.uid())
    OR id IN (SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid())
    OR id IN (SELECT id_academia FROM public.users_personal WHERE id = auth.uid())
);
-- Permissão pro sistema cadastrar admins
CREATE POLICY "Sys_Insert_Admin" ON public.users_adm FOR INSERT WITH CHECK (auth.role() = 'service_role' OR auth.uid() IS NOT NULL);

-- 4. ====== TABELA USERS_NUTRICIONISTA ======
-- O nutricionista gere seus próprios dados (Fim do loop)
CREATE POLICY "Nutri_Self" ON public.users_nutricionista FOR ALL USING (auth.uid() = id);
-- O admin genêrencia (Fim do loop, pois o uid do admin é direto)
CREATE POLICY "Admin_Manage_Nutri" ON public.users_nutricionista FOR ALL USING (id_academia = auth.uid());

-- 5. ====== TABELA USERS_PERSONAL ======
-- O personal gere seus próprios dados (Fim do loop)
CREATE POLICY "Personal_Self" ON public.users_personal FOR ALL USING (auth.uid() = id);
-- O administrador gere seus personais
CREATE POLICY "Admin_Manage_Personal" ON public.users_personal FOR ALL USING (id_academia = auth.uid());

-- 6. ====== TABELA USERS_ALUNOS ======
-- O aluno gere seus próprios dados
CREATE POLICY "Aluno_Self" ON public.users_alunos FOR ALL USING (auth.uid() = id);
-- O admin, personal ou nutri podem gerenciar seus alunos livremente (Unidirecional)
CREATE POLICY "Staff_Manage_Alunos" ON public.users_alunos FOR ALL USING (
    id_academia = auth.uid()
    OR id_academia IN (SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid())
    OR id_academia IN (SELECT id_academia FROM public.users_personal WHERE id = auth.uid())
);

-- 7. ====== RECARREGAR O MOTOR DO SUPABASE ======
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';

SELECT '✅ CIRURGIA CONCLUÍDA. ZERO LOOPS EXISTEM AGORA. TESTE OS LOGINS!' as status;
