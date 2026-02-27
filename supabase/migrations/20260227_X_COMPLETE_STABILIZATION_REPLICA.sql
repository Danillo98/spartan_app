-- ============================================================
-- SOLUÇÃO DEFINITIVA DE ESTABILIZAÇÃO (REPLICA DO SUCESSO)
-- v2.6.2 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Este script restaura a compatibilidade total e elimina o erro
-- "Database error querying schema" restaurando as colunas
-- necessárias e corrigindo a recursão de RLS.
-- ============================================================

-- 1. RESTAURAR COMPATIBILIDADE DE COLUNAS (O que resolveu ontem)
-- ============================================================
ALTER TABLE public.users_adm ADD COLUMN IF NOT EXISTS cnpj_academia TEXT;
ALTER TABLE public.users_nutricionista ADD COLUMN IF NOT EXISTS cnpj_academia TEXT;
ALTER TABLE public.users_personal ADD COLUMN IF NOT EXISTS cnpj_academia TEXT;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS cnpj_academia TEXT;

-- Garantir colunas de controle financeiro nos alunos
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS payment_due_day INT DEFAULT 10;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS status_financeiro TEXT DEFAULT 'pending';
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS next_payment_due DATE;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS data_nascimento DATE;


-- 2. LIMPEZA TOTAL DE POLÍTICAS (PREPARAÇÃO)
-- ============================================================
DROP POLICY IF EXISTS "Admin pode ver próprio registro" ON public.users_adm;
DROP POLICY IF EXISTS "Membros podem ver admin da academia" ON public.users_adm;
DROP POLICY IF EXISTS "Profissionais podem ver admin da academia" ON public.users_adm;

DROP POLICY IF EXISTS "Nutricionista pode ver próprio perfil" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Nutricionistas podem ver próprio perfil" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Admin pode ver nutricionistas da academia" ON public.users_nutricionista;
DROP POLICY IF EXISTS "Admin pode gerenciar nutricionistas" ON public.users_nutricionista;

DROP POLICY IF EXISTS "Personal pode ver próprio perfil" ON public.users_personal;
DROP POLICY IF EXISTS "Admin pode ver personals da academia" ON public.users_personal;
DROP POLICY IF EXISTS "Admin pode gerenciar personals" ON public.users_personal;

DROP POLICY IF EXISTS "Aluno pode ver próprio perfil" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Nutricionista pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Personal pode ver alunos da academia" ON public.users_alunos;
DROP POLICY IF EXISTS "Admin gerencia alunos" ON public.users_alunos;


-- 3. RECRIAR POLÍTICAS NÃO-RECURSIVAS (O PADRÃO QUE FUNCIONA)
-- ============================================================

-- A) USERS_ADM
CREATE POLICY "Admin pode ver próprio perfil" ON public.users_adm FOR SELECT USING (id = auth.uid());
-- Alunos e Profissionais vêem o Admin da sua academia (pelo ID)
CREATE POLICY "Membros vêem admin" ON public.users_adm FOR SELECT USING (
  id = (SELECT id_academia FROM public.users_alunos WHERE id = auth.uid()) OR
  id = (SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()) OR
  id = (SELECT id_academia FROM public.users_personal WHERE id = auth.uid())
);

-- B) USERS_NUTRICIONISTA
CREATE POLICY "Nutricionista vê próprio perfil" ON public.users_nutricionista FOR SELECT USING (id = auth.uid());
CREATE POLICY "Admin vê seus nutricionistas" ON public.users_nutricionista FOR SELECT USING (id_academia = auth.uid());
CREATE POLICY "Admin gerencia seus nutricionistas" ON public.users_nutricionista FOR ALL USING (id_academia = auth.uid());

-- C) USERS_PERSONAL
CREATE POLICY "Personal vê próprio perfil" ON public.users_personal FOR SELECT USING (id = auth.uid());
CREATE POLICY "Admin vê seus personals" ON public.users_personal FOR SELECT USING (id_academia = auth.uid());
CREATE POLICY "Admin gerencia seus personals" ON public.users_personal FOR ALL USING (id_academia = auth.uid());

-- D) USERS_ALUNOS
CREATE POLICY "Aluno vê próprio perfil" ON public.users_alunos FOR SELECT USING (id = auth.uid());
CREATE POLICY "Admin vê seus alunos" ON public.users_alunos FOR SELECT USING (id_academia = auth.uid());
CREATE POLICY "Admin gerencia seus alunos" ON public.users_alunos FOR ALL USING (id_academia = auth.uid());
-- Profissionais vêem alunos da mesma academia
CREATE POLICY "Nutri vê alunos" ON public.users_alunos FOR SELECT USING (
  id_academia = (SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid())
);
CREATE POLICY "Personal vê alunos" ON public.users_alunos FOR SELECT USING (
  id_academia = (SELECT id_academia FROM public.users_personal WHERE id = auth.uid())
);


-- 4. ATUALIZAR CREATE_USER_V4 (O "MOTOR")
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_user_v4(
    p_email TEXT,
    p_password TEXT,
    p_metadata JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_user_id UUID;
    user_role TEXT;
    user_name TEXT;
    user_phone TEXT;
    user_id_academia UUID;
    user_cnpj TEXT;
    v_payment_day INT;
    v_birth DATE;
BEGIN
    user_role := p_metadata->>'role';
    user_name := p_metadata->>'name';
    user_phone := p_metadata->>'phone';
    user_id_academia := (p_metadata->>'id_academia')::UUID;
    user_cnpj := p_metadata->>'cnpj_academia';
    v_payment_day := (p_metadata->>'paymentDueDay')::INT;
    v_birth := (p_metadata->>'birthDate')::DATE;

    -- 1. Criar no Auth
    INSERT INTO auth.users (
        id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at, role, aud
    ) VALUES (
        gen_random_uuid(), p_email, crypt(p_password, gen_salt('bf')), NOW(), p_metadata, NOW(), NOW(), 'authenticated', 'authenticated'
    ) RETURNING id INTO new_user_id;

    -- 2. Inserir na tabela pública conforme o cargo
    IF user_role = 'nutritionist' THEN
        INSERT INTO public.users_nutricionista (id, nome, email, telefone, id_academia, cnpj_academia, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_id_academia, user_cnpj, TRUE, NOW(), NOW());
    ELSIF user_role = 'trainer' THEN
        INSERT INTO public.users_personal (id, nome, email, telefone, id_academia, cnpj_academia, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_id_academia, user_cnpj, TRUE, NOW(), NOW());
    ELSIF user_role = 'student' THEN
        INSERT INTO public.users_alunos (id, nome, email, telefone, id_academia, cnpj_academia, payment_due_day, data_nascimento, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_id_academia, user_cnpj, v_payment_day, v_birth, TRUE, NOW(), NOW());
    END IF;

    RETURN jsonb_build_object('success', TRUE, 'user_id', new_user_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'message', SQLERRM);
END;
$$;


-- 5. RECARGA FINAL DO SISTEMA (ANTIDOTO)
-- ============================================================
NOTIFY pgrst, 'reload schema';

SELECT '✅ Sistema Spartans v2.6.2 RESTAURADO! Use o novo arquivo de login.' as status;
