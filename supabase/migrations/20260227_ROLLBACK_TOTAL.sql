-- ============================================================
-- SCRIPT DE REVERSÃO - CORREÇÃO DE POLÍTICAS EXISTENTES
-- ============================================================

-- Primeiro, deletamos qualquer uma das políticas alvo para evitar o erro "already exists"
DROP POLICY IF EXISTS "Aluno pode ver próprio perfil" ON public.users_alunos;
DROP POLICY IF EXISTS "Aluno pode atualizar próprio perfil" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Nutricionista pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Personal pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode criar alunos" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode atualizar alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode deletar alunos da academia" ON public.users_alunos;

DROP POLICY IF EXISTS "Admin pode ver próprio registro" ON public.users_adm;
DROP POLICY IF EXISTS "Admin pode atualizar próprio registro" ON public.users_adm;
DROP POLICY IF EXISTS "Service Role pode inserir admin" ON public.users_adm;
DROP POLICY IF EXISTS "Membros podem ver admin da academia" ON public.users_adm;

DROP POLICY IF EXISTS "Acesso proprio perfil nutri" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Acesso proprio perfil personal" ON public.users_personal;

-- A) USERS ALUNOS (A PRIORIDADE)
CREATE POLICY "Aluno pode ver próprio perfil" ON public.users_alunos 
FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Aluno pode atualizar próprio perfil" ON public.users_alunos 
FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admin pode ver alunos da academia" ON public.users_alunos 
FOR SELECT USING ( id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid()) );

CREATE POLICY "Nutricionista pode ver alunos da academia" ON public.users_alunos 
FOR SELECT USING ( id_academia IN (SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()) );

CREATE POLICY "Personal pode ver alunos da academia" ON public.users_alunos 
FOR SELECT USING ( id_academia IN (SELECT id_academia FROM public.users_personal WHERE id = auth.uid()) );

CREATE POLICY "Admin pode criar alunos" ON public.users_alunos 
FOR INSERT WITH CHECK ( id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid()) OR auth.role() = 'service_role' );

CREATE POLICY "Admin pode atualizar alunos da academia" ON public.users_alunos 
FOR UPDATE USING ( id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid()) );

CREATE POLICY "Admin pode deletar alunos da academia" ON public.users_alunos 
FOR DELETE USING ( id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid()) );

-- B) USERS ADM
CREATE POLICY "Admin pode ver próprio registro" ON public.users_adm 
FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Admin pode atualizar próprio registro" ON public.users_adm 
FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Service Role pode inserir admin" ON public.users_adm 
FOR INSERT WITH CHECK (auth.role() = 'service_role' OR auth.uid() IS NOT NULL);

CREATE POLICY "Membros podem ver admin da academia" ON public.users_adm 
FOR SELECT USING (
  id IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
    UNION
    SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
    UNION
    SELECT id_academia FROM public.users_alunos WHERE id = auth.uid()
  )
);

-- C) USERS NUTRICIONISTA & USERS PERSONAL
CREATE POLICY "Acesso proprio perfil nutri" ON public.users_nutricionista 
FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Acesso proprio perfil personal" ON public.users_personal 
FOR SELECT USING (auth.uid() = id);

-- 3. PERMISSÕES BÁSICAS (GRANTS)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';

SELECT '✅ REVERSÃO TOTAL CONCLUÍDA! O sistema voltou para as regras de ontem. Teste os ALUNOS.' as status;
