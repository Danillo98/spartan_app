-- ============================================================
-- RESTAURAÇÃO DEFINITIVA SPARTAN APP - v2.6.1
-- Resolve: Todos usuários sem acesso após limpeza de políticas
-- ============================================================
-- PROBLEMA IDENTIFICADO: Ao dropar as políticas, os usuários 
-- não conseguem logar pois o RLS está ativado mas VAZIO.
-- Com RLS ligado e zero políticas, o Postgres bloqueia TUDO.
-- Este script recria políticas simples, diretas e sem recursão.
-- ============================================================

-- PASSO 0: Limpar qualquer resíduo de funções bomba anteriores
DROP FUNCTION IF EXISTS public.get_auth_academy_id() CASCADE;

-- ============================================================
-- PARTE 1: users_adm
-- ============================================================
ALTER TABLE public.users_adm ENABLE ROW LEVEL SECURITY;

-- Dropar políticas existentes pelo nome
DROP POLICY IF EXISTS "Admin pode ver próprio registro" ON public.users_adm;
DROP POLICY IF EXISTS "Membros podem ver admin da academia" ON public.users_adm;
DROP POLICY IF EXISTS "Admin pode atualizar próprio registro" ON public.users_adm;
DROP POLICY IF EXISTS "Service Role pode inserir admin" ON public.users_adm;
DROP POLICY IF EXISTS "JWT_ADM_ALL" ON public.users_adm;
DROP POLICY IF EXISTS "ADM_SELECT" ON public.users_adm;
DROP POLICY IF EXISTS "ADM_INSERT" ON public.users_adm;
DROP POLICY IF EXISTS "ADM_UPDATE" ON public.users_adm;

-- Admin vê/edita apenas seu próprio registro (SEM subqueries em outras tabelas)
CREATE POLICY "ADM_SELECT" ON public.users_adm
FOR SELECT USING (auth.uid() = id);

CREATE POLICY "ADM_UPDATE" ON public.users_adm
FOR UPDATE USING (auth.uid() = id);

-- INSERT: service_role (para criar admin via webhook/RPC) ou qualquer autenticado
CREATE POLICY "ADM_INSERT" ON public.users_adm
FOR INSERT WITH CHECK (
  auth.role() = 'service_role' OR auth.uid() IS NOT NULL
);


-- ============================================================
-- PARTE 2: users_alunos
-- ============================================================
ALTER TABLE public.users_alunos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Aluno pode ver próprio perfil" ON public.users_alunos;
DROP POLICY IF EXISTS "Aluno pode atualizar próprio perfil" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode criar alunos" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode atualizar alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode deletar alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Nutricionista pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Personal pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "JWT_ALUNOS_ALL" ON public.users_alunos;
DROP POLICY IF EXISTS "ALUNO_SELECT" ON public.users_alunos;
DROP POLICY IF EXISTS "ALUNO_INSERT" ON public.users_alunos;
DROP POLICY IF EXISTS "ALUNO_UPDATE" ON public.users_alunos;
DROP POLICY IF EXISTS "ALUNO_DELETE" ON public.users_alunos;

-- SELECT: Aluno vê o próprio; anon/authenticated vê pela academia (sem subquery recursiva!)
-- ESTRATÉGIA: Apenas auth.uid() = id para o próprio usuário.
-- Admin e staff acessam via service_role (RPC SECURITY DEFINER) - sem usar subquery em users_adm
CREATE POLICY "ALUNO_SELECT" ON public.users_alunos
FOR SELECT USING (
  auth.uid() = id
  OR auth.role() = 'service_role'
  OR (auth.uid() IS NOT NULL AND id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia'))
);

CREATE POLICY "ALUNO_UPDATE" ON public.users_alunos
FOR UPDATE USING (
  auth.uid() = id
  OR auth.role() = 'service_role'
  OR (auth.uid() IS NOT NULL AND id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia'))
);

CREATE POLICY "ALUNO_INSERT" ON public.users_alunos
FOR INSERT WITH CHECK (
  auth.role() = 'service_role' OR auth.uid() IS NOT NULL
);

CREATE POLICY "ALUNO_DELETE" ON public.users_alunos
FOR DELETE USING (
  auth.role() = 'service_role'
  OR (auth.uid() IS NOT NULL AND id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia'))
);


-- ============================================================
-- PARTE 3: users_nutricionista
-- ============================================================
ALTER TABLE public.users_nutricionista ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "JWT_NUTRI_ALL" ON public.users_nutricionista;
DROP POLICY IF EXISTS "NUTRI_SELECT" ON public.users_nutricionista;
DROP POLICY IF EXISTS "NUTRI_INSERT" ON public.users_nutricionista;
DROP POLICY IF EXISTS "NUTRI_UPDATE" ON public.users_nutricionista;
DROP POLICY IF EXISTS "NUTRI_DELETE" ON public.users_nutricionista;

CREATE POLICY "NUTRI_SELECT" ON public.users_nutricionista
FOR SELECT USING (
  auth.uid() = id
  OR auth.role() = 'service_role'
  OR (auth.uid() IS NOT NULL AND id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia'))
);

CREATE POLICY "NUTRI_UPDATE" ON public.users_nutricionista
FOR UPDATE USING (
  auth.uid() = id
  OR auth.role() = 'service_role'
  OR (auth.uid() IS NOT NULL AND id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia'))
);

CREATE POLICY "NUTRI_INSERT" ON public.users_nutricionista
FOR INSERT WITH CHECK (
  auth.role() = 'service_role' OR auth.uid() IS NOT NULL
);

CREATE POLICY "NUTRI_DELETE" ON public.users_nutricionista
FOR DELETE USING (
  auth.role() = 'service_role'
  OR (auth.uid() IS NOT NULL AND id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia'))
);


-- ============================================================
-- PARTE 4: users_personal
-- ============================================================
ALTER TABLE public.users_personal ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "JWT_PERSONAL_ALL" ON public.users_personal;
DROP POLICY IF EXISTS "PERSONAL_SELECT" ON public.users_personal;
DROP POLICY IF EXISTS "PERSONAL_INSERT" ON public.users_personal;
DROP POLICY IF EXISTS "PERSONAL_UPDATE" ON public.users_personal;
DROP POLICY IF EXISTS "PERSONAL_DELETE" ON public.users_personal;

CREATE POLICY "PERSONAL_SELECT" ON public.users_personal
FOR SELECT USING (
  auth.uid() = id
  OR auth.role() = 'service_role'
  OR (auth.uid() IS NOT NULL AND id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia'))
);

CREATE POLICY "PERSONAL_UPDATE" ON public.users_personal
FOR UPDATE USING (
  auth.uid() = id
  OR auth.role() = 'service_role'
  OR (auth.uid() IS NOT NULL AND id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia'))
);

CREATE POLICY "PERSONAL_INSERT" ON public.users_personal
FOR INSERT WITH CHECK (
  auth.role() = 'service_role' OR auth.uid() IS NOT NULL
);

CREATE POLICY "PERSONAL_DELETE" ON public.users_personal
FOR DELETE USING (
  auth.role() = 'service_role'
  OR (auth.uid() IS NOT NULL AND id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia'))
);


-- ============================================================
-- PARTE 5: GRANTS (Garantir que o PostgREST tem acesso)
-- ============================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users_adm TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users_alunos TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users_nutricionista TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users_personal TO authenticated;

-- ============================================================
-- PARTE 6: FORÇAR RELOAD DO SCHEMA
-- ============================================================
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';

-- VERIFICAÇÃO FINAL
SELECT 
  tablename,
  rowsecurity as "RLS_Ativo",
  (SELECT COUNT(*) FROM pg_policies p WHERE p.tablename = t.tablename AND p.schemaname = 'public') as "Num_Politicas"
FROM pg_tables t
WHERE schemaname = 'public'
AND tablename IN ('users_adm', 'users_alunos', 'users_nutricionista', 'users_personal')
ORDER BY tablename;

SELECT '✅ RESTAURAÇÃO DEFINITIVA CONCLUÍDA! Todos os usuários podem logar novamente.' as status;
