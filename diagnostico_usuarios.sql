-- ============================================
-- SCRIPT DE LIMPEZA E DIAGNÓSTICO
-- ============================================

-- 1. DIAGNÓSTICO: Verificar usuários no Auth que não estão na tabela users
-- ============================================

SELECT 
    au.id,
    au.email,
    au.email_confirmed_at,
    au.created_at,
    CASE 
        WHEN pu.id IS NULL THEN '❌ NÃO EXISTE'
        ELSE '✅ EXISTE'
    END as status_na_tabela_users
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
ORDER BY au.created_at DESC;

-- 2. LISTAR USUÁRIOS PROBLEMÁTICOS
-- ============================================
-- Usuários que confirmaram email mas não estão na tabela users

SELECT 
    au.id,
    au.email,
    au.email_confirmed_at,
    au.created_at
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
  AND au.email_confirmed_at IS NOT NULL;

-- 3. LIMPEZA: Deletar usuários do Auth que não estão na tabela users
-- ============================================
-- ⚠️ CUIDADO: Execute apenas se tiver certeza!
-- ⚠️ Isso vai deletar usuários do sistema de autenticação

-- DESCOMENTE PARA EXECUTAR:
/*
DELETE FROM auth.users
WHERE id IN (
    SELECT au.id
    FROM auth.users au
    LEFT JOIN public.users pu ON au.id = pu.id
    WHERE pu.id IS NULL
);
*/

-- 4. VERIFICAR USUÁRIO ESPECÍFICO
-- ============================================
-- Substitua 'seu@email.com' pelo email do usuário

DO $$
DECLARE
    v_email TEXT := 'danilloneto98@gmail.com'; -- MUDE AQUI
    v_auth_user RECORD;
    v_public_user RECORD;
BEGIN
    -- Buscar no auth.users
    SELECT id, email, email_confirmed_at, created_at
    INTO v_auth_user
    FROM auth.users
    WHERE email = v_email;

    -- Buscar no public.users
    SELECT id, name, email, role
    INTO v_public_user
    FROM public.users
    WHERE email = v_email;

    -- Mostrar resultados
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DIAGNÓSTICO PARA: %', v_email;
    RAISE NOTICE '========================================';
    
    IF v_auth_user IS NOT NULL THEN
        RAISE NOTICE '✅ Existe no auth.users:';
        RAISE NOTICE '   ID: %', v_auth_user.id;
        RAISE NOTICE '   Email: %', v_auth_user.email;
        RAISE NOTICE '   Confirmado em: %', v_auth_user.email_confirmed_at;
        RAISE NOTICE '   Criado em: %', v_auth_user.created_at;
    ELSE
        RAISE NOTICE '❌ NÃO existe no auth.users';
    END IF;

    RAISE NOTICE '';

    IF v_public_user IS NOT NULL THEN
        RAISE NOTICE '✅ Existe no public.users:';
        RAISE NOTICE '   ID: %', v_public_user.id;
        RAISE NOTICE '   Nome: %', v_public_user.name;
        RAISE NOTICE '   Email: %', v_public_user.email;
        RAISE NOTICE '   Role: %', v_public_user.role;
    ELSE
        RAISE NOTICE '❌ NÃO existe no public.users';
    END IF;

    RAISE NOTICE '========================================';
END $$;

-- 5. LIMPEZA ESPECÍFICA: Deletar usuário específico do Auth
-- ============================================
-- ⚠️ Use apenas se o usuário não está na tabela users

-- DESCOMENTE PARA EXECUTAR:
/*
DELETE FROM auth.users
WHERE email = 'danilloneto98@gmail.com'; -- MUDE AQUI
*/

-- 6. VERIFICAR TOTAL DE USUÁRIOS
-- ============================================

SELECT 
    'auth.users' as tabela,
    COUNT(*) as total
FROM auth.users
UNION ALL
SELECT 
    'public.users' as tabela,
    COUNT(*) as total
FROM public.users;

-- 7. CRIAR USUÁRIO MANUALMENTE NA TABELA USERS (SE NECESSÁRIO)
-- ============================================
-- Use apenas se o usuário existe no auth.users mas não no public.users
-- E você tem todos os dados necessários

-- DESCOMENTE E PREENCHA OS DADOS:
/*
INSERT INTO public.users (
    id,
    name,
    email,
    phone,
    password_hash,
    role,
    cnpj,
    cpf,
    address,
    email_verified
)
SELECT 
    au.id,
    'NOME_AQUI',                    -- MUDE AQUI
    au.email,
    'TELEFONE_AQUI',                -- MUDE AQUI
    'managed_by_supabase_auth',
    'admin',
    'CNPJ_AQUI',                    -- MUDE AQUI
    'CPF_AQUI',                     -- MUDE AQUI
    'ENDERECO_AQUI',                -- MUDE AQUI
    true
FROM auth.users au
WHERE au.email = 'seu@email.com'   -- MUDE AQUI
  AND NOT EXISTS (
      SELECT 1 FROM public.users pu WHERE pu.id = au.id
  );
*/
