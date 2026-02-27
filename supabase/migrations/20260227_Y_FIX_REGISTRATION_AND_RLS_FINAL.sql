-- ============================================================
-- FIX DEFINITIVO: CADASTRO E LOGIN (RLS LOOP)
-- v2.6.3 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- 1. Resolve o erro "null value in column academia" no cadastro.
-- 2. Resolve o "Database error querying schema" no login usando
--    função SECURITY DEFINER para quebrar a recursão.
-- ============================================================

-- 1. FUNÇÃO DE LOOKUP SEGURA (Bypassa RLS para evitar loops)
-- ============================================================
CREATE OR REPLACE FUNCTION public.safe_get_academy_id(p_user_id UUID)
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT id_academia FROM public.users_alunos WHERE id = p_user_id
        UNION
        SELECT id_academia FROM public.users_nutricionista WHERE id = p_user_id
        UNION
        SELECT id_academia FROM public.users_personal WHERE id = p_user_id
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. ATUALIZAR CREATE_USER_V4 (FIX ERRO ACADEMIA NULL)
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
    user_academia TEXT;
    user_id_academia UUID;
    user_cnpj TEXT;
    v_payment_day INT;
    v_birth DATE;
BEGIN
    -- Extrair metadados
    user_role := p_metadata->>'role';
    user_name := p_metadata->>'name';
    user_phone := p_metadata->>'phone';
    user_id_academia := (p_metadata->>'id_academia')::UUID;
    user_cnpj := p_metadata->>'cnpj_academia';
    user_academia := p_metadata->>'academia';
    v_payment_day := (p_metadata->>'paymentDueDay')::INT;
    v_birth := (p_metadata->>'birthDate')::DATE;

    -- Se não veio o nome da academia, buscar do Admin
    IF user_academia IS NULL THEN
        SELECT academia INTO user_academia FROM public.users_adm WHERE id = user_id_academia;
    END IF;

    -- 1. Criar no Auth
    INSERT INTO auth.users (
        id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at, role, aud, instance_id
    ) VALUES (
        gen_random_uuid(), p_email, crypt(p_password, gen_salt('bf')), NOW(), p_metadata, NOW(), NOW(), 'authenticated', 'authenticated', '00000000-0000-0000-0000-000000000000'
    ) RETURNING id INTO new_user_id;

    -- 2. Inserir na tabela pública com todas as colunas obrigatórias
    IF user_role = 'nutritionist' THEN
        INSERT INTO public.users_nutricionista (id, nome, email, telefone, id_academia, cnpj_academia, academia, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_id_academia, user_cnpj, user_academia, TRUE, NOW(), NOW());
    ELSIF user_role = 'trainer' THEN
        INSERT INTO public.users_personal (id, nome, email, telefone, id_academia, cnpj_academia, academia, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_id_academia, user_cnpj, user_academia, TRUE, NOW(), NOW());
    ELSIF user_role = 'student' THEN
        INSERT INTO public.users_alunos (id, nome, email, telefone, id_academia, cnpj_academia, academia, payment_due_day, data_nascimento, email_verified, created_at, updated_at)
        VALUES (new_user_id, user_name, p_email, user_phone, user_id_academia, user_cnpj, user_id_academia, v_payment_day, v_birth, TRUE, NOW(), NOW());
    END IF;

    RETURN jsonb_build_object('success', TRUE, 'user_id', new_user_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'message', SQLERRM);
END;
$$;


-- 3. RECRIAR RLS USANDO A FUNÇÃO SEGURA (DESTRAVA LOGIN)
-- ============================================================

-- Bypassa o loop infinito na users_adm
DROP POLICY IF EXISTS "Membros vêem admin" ON public.users_adm;
CREATE POLICY "Membros vêem admin" ON public.users_adm FOR SELECT 
USING ( id = public.safe_get_academy_id(auth.uid()) );

-- Bypassa o loop na users_alunos (para nutricionistas e personais verem)
DROP POLICY IF EXISTS "Nutri vê alunos" ON public.users_alunos;
CREATE POLICY "Nutri vê alunos" ON public.users_alunos FOR SELECT 
USING ( id_academia = public.safe_get_academy_id(auth.uid()) );

DROP POLICY IF EXISTS "Personal vê alunos" ON public.users_alunos;
CREATE POLICY "Personal vê alunos" ON public.users_alunos FOR SELECT 
USING ( id_academia = public.safe_get_academy_id(auth.uid()) );


-- 4. RECARGA FINAL DO CACHE DA API
-- ============================================================
NOTIFY pgrst, 'reload schema';

SELECT '✅ Fix Y aplicado: Cadastro corrigido e Loop de RLS quebrado!' as status;
