-- =============================================================================
-- CORREÇÃO DE PERMISSÕES DE INSERT (RLS)
-- =============================================================================
-- Este script corrige o erro "new row violates row-level security policy".
-- Ele permite explicitamente que usuários autenticados criem seus próprios perfis.

-- 1. Tabela Nutricionista
ALTER TABLE public.users_nutricionista ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir Insert Proprio Nutri" ON public.users_nutricionista;
CREATE POLICY "Permitir Insert Proprio Nutri" ON public.users_nutricionista
FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Permitir Select Proprio Nutri" ON public.users_nutricionista;
CREATE POLICY "Permitir Select Proprio Nutri" ON public.users_nutricionista
FOR SELECT USING (auth.uid() = id);

GRANT ALL ON public.users_nutricionista TO authenticated;
GRANT ALL ON public.users_nutricionista TO service_role;


-- 2. Tabela Personal
ALTER TABLE public.users_personal ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir Insert Proprio Personal" ON public.users_personal;
CREATE POLICY "Permitir Insert Proprio Personal" ON public.users_personal
FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Permitir Select Proprio Personal" ON public.users_personal;
CREATE POLICY "Permitir Select Proprio Personal" ON public.users_personal
FOR SELECT USING (auth.uid() = id);

GRANT ALL ON public.users_personal TO authenticated;
GRANT ALL ON public.users_personal TO service_role;


-- 3. Tabela Alunos
ALTER TABLE public.users_alunos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir Insert Proprio Aluno" ON public.users_alunos;
CREATE POLICY "Permitir Insert Proprio Aluno" ON public.users_alunos
FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Permitir Select Proprio Aluno" ON public.users_alunos;
CREATE POLICY "Permitir Select Proprio Aluno" ON public.users_alunos
FOR SELECT USING (auth.uid() = id);

GRANT ALL ON public.users_alunos TO authenticated;
GRANT ALL ON public.users_alunos TO service_role;


-- 4. Tabela Admin (Garantia)
ALTER TABLE public.users_adm ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir Insert Proprio Adm" ON public.users_adm;
CREATE POLICY "Permitir Insert Proprio Adm" ON public.users_adm
FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Permitir Select Proprio Adm" ON public.users_adm;
CREATE POLICY "Permitir Select Proprio Adm" ON public.users_adm
FOR SELECT USING (auth.uid() = id);

GRANT ALL ON public.users_adm TO authenticated;
GRANT ALL ON public.users_adm TO service_role;

SELECT 'Permissões de INSERT corrigidas com sucesso!' as status;
