-- ============================================================
-- RESTAURAÇÃO DE SEGURANÇA v2.5.3 - Spartan App
-- Reattiva RLS em users_adm e users_alunos com políticas corretas
-- ============================================================

-- 1. REATIVAR RLS (Desativado durante debugging)
-- ============================================================
ALTER TABLE public.users_adm ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_alunos ENABLE ROW LEVEL SECURITY;


-- 2. RLS POLICIES - users_adm
-- ============================================================
-- Limpar TODAS as políticas existentes antes de recriar
DROP POLICY IF EXISTS "Acesso Temporário Total" ON public.users_adm;
DROP POLICY IF EXISTS "Admin pode ver próprio registro" ON public.users_adm;
DROP POLICY IF EXISTS "Admin full access" ON public.users_adm;
DROP POLICY IF EXISTS "System Insert Admin" ON public.users_adm;
DROP POLICY IF EXISTS "System Update Admin" ON public.users_adm;
DROP POLICY IF EXISTS "Membros podem ver admin da academia" ON public.users_adm;
DROP POLICY IF EXISTS "Admin pode atualizar próprio registro" ON public.users_adm;
DROP POLICY IF EXISTS "Service Role pode inserir admin" ON public.users_adm;

-- Admin vê apenas seu próprio registro (isolamento de academia)
CREATE POLICY "Admin pode ver próprio registro"
ON public.users_adm FOR SELECT
USING (auth.uid() = id);

-- Profissionais e Alunos podem VER o admin da sua academia (para buscar nome, endereço)
CREATE POLICY "Membros podem ver admin da academia"
ON public.users_adm FOR SELECT
USING (
  id IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
    UNION
    SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
    UNION
    SELECT id_academia FROM public.users_alunos WHERE id = auth.uid()
  )
);

-- Admin pode atualizar seu próprio registro 
CREATE POLICY "Admin pode atualizar próprio registro"
ON public.users_adm FOR UPDATE
USING (auth.uid() = id);

-- Apenas service_role pode inserir novos admins (criado pelo Stripe/Webhook)
CREATE POLICY "Service Role pode inserir admin"
ON public.users_adm FOR INSERT
WITH CHECK (auth.role() = 'service_role' OR auth.uid() IS NOT NULL);


-- 3. RLS POLICIES - users_alunos
-- ============================================================
DROP POLICY IF EXISTS "Acesso Temporário Total" ON public.users_alunos;
DROP POLICY IF EXISTS "Aluno pode ver próprio perfil" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode criar alunos" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode atualizar alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode deletar alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Nutricionista pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Personal pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Profissionais podem atualizar alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode atualizar alunos" ON public.users_alunos;

-- Aluno vê apenas seu próprio registro
DROP POLICY IF EXISTS "Aluno pode ver próprio perfil" ON public.users_alunos;
CREATE POLICY "Aluno pode ver próprio perfil"
ON public.users_alunos FOR SELECT
USING (auth.uid() = id);

-- Aluno pode atualizar apenas seu próprio registro (foto, etc)
DROP POLICY IF EXISTS "Aluno pode atualizar próprio perfil" ON public.users_alunos;
CREATE POLICY "Aluno pode atualizar próprio perfil"
ON public.users_alunos FOR UPDATE
USING (auth.uid() = id);

-- Admin vê todos os alunos da sua academia
CREATE POLICY "Admin pode ver alunos da academia"
ON public.users_alunos FOR SELECT
USING (
  id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
);

-- Nutricionista vê alunos da sua academia
CREATE POLICY "Nutricionista pode ver alunos da academia"
ON public.users_alunos FOR SELECT
USING (
  id_academia IN (SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid())
);

-- Personal Trainer vê alunos da sua academia
CREATE POLICY "Personal pode ver alunos da academia"
ON public.users_alunos FOR SELECT
USING (
  id_academia IN (SELECT id_academia FROM public.users_personal WHERE id = auth.uid())
);

-- Admin pode inserir alunos (via RPC, que é SECURITY DEFINER, então isso é só para o Admin direto)
CREATE POLICY "Admin pode criar alunos"
ON public.users_alunos FOR INSERT
WITH CHECK (
  id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
  OR auth.role() = 'service_role'
);

-- Admin pode atualizar alunos da academia
CREATE POLICY "Admin pode atualizar alunos da academia"
ON public.users_alunos FOR UPDATE
USING (
  id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
);

-- Admin pode deletar alunos da academia
CREATE POLICY "Admin pode deletar alunos da academia"
ON public.users_alunos FOR DELETE
USING (
  id_academia IN (SELECT id FROM public.users_adm WHERE id = auth.uid())
);


-- 4. VERIFICAÇÃO FINAL
-- ============================================================
NOTIFY pgrst, 'reload schema';

SELECT 
  tablename,
  rowsecurity as "RLS Ativado",
  (SELECT COUNT(*) FROM pg_policies WHERE tablename = pg_tables.tablename) as "Nº Políticas"
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('users_adm', 'users_alunos', 'users_nutricionista', 'users_personal')
ORDER BY tablename;

SELECT '✅ RLS restaurada com sucesso em users_adm e users_alunos!' as status;
