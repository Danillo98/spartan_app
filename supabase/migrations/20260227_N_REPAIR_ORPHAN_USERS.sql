-- ============================================================
-- REPARO: Usuários Órfãos (auth.users SEM tabela pública)
-- v2.5.5 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- CAUSA: create_user_v4 tentava inserir coluna 'cnpj_academia'
-- que foi removida nas tables users_nutricionista e users_personal
-- pelos scripts FINAL_CLEANUP_CNPJ.sql e CASCADE_CLEANUP_CNPJ.sql.
-- A INSERT falhava, mas como o auth.users já havia sido criado,
-- o usuário ficou "fantasma" — autenticável, mas sem perfil.
-- ============================================================

-- ============================================================
-- PASSO 1: DIAGNÓSTICO - Ver usuários órfãos
-- ============================================================
-- (Execute esta parte primeiro para confirmar os órfãos)
SELECT 
    au.id,
    au.email,
    au.raw_user_meta_data->>'role' as role,
    au.raw_user_meta_data->>'name' as nome,
    au.created_at
FROM auth.users au
WHERE au.raw_user_meta_data->>'role' IN ('nutritionist', 'trainer')
  AND NOT EXISTS (
    SELECT 1 FROM public.users_nutricionista un WHERE un.id = au.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.users_personal up WHERE up.id = au.id
  )
ORDER BY au.created_at DESC;


-- ============================================================
-- PASSO 2: REPARAR - Inserir nutricionistas órfãos
-- ============================================================
INSERT INTO public.users_nutricionista (
    id,
    nome,
    email,
    telefone,
    academia,
    id_academia,
    created_by_admin_id,
    email_verified,
    is_blocked,
    created_at,
    updated_at
)
SELECT
    au.id,
    COALESCE(au.raw_user_meta_data->>'name', 'Nutricionista'),
    au.email,
    COALESCE(au.raw_user_meta_data->>'phone', ''),
    COALESCE(au.raw_user_meta_data->>'academia', 'Academia'),
    (au.raw_user_meta_data->>'id_academia')::UUID,
    COALESCE(
        (au.raw_user_meta_data->>'created_by_admin_id')::UUID,
        (au.raw_user_meta_data->>'id_academia')::UUID
    ),
    TRUE,
    FALSE,
    au.created_at,
    NOW()
FROM auth.users au
WHERE au.raw_user_meta_data->>'role' = 'nutritionist'
  AND NOT EXISTS (
    SELECT 1 FROM public.users_nutricionista un WHERE un.id = au.id
  )
  AND (au.raw_user_meta_data->>'id_academia') IS NOT NULL;


-- ============================================================
-- PASSO 3: REPARAR - Inserir personal trainers órfãos
-- ============================================================
INSERT INTO public.users_personal (
    id,
    nome,
    email,
    telefone,
    academia,
    id_academia,
    created_by_admin_id,
    email_verified,
    is_blocked,
    created_at,
    updated_at
)
SELECT
    au.id,
    COALESCE(au.raw_user_meta_data->>'name', 'Personal Trainer'),
    au.email,
    COALESCE(au.raw_user_meta_data->>'phone', ''),
    COALESCE(au.raw_user_meta_data->>'academia', 'Academia'),
    (au.raw_user_meta_data->>'id_academia')::UUID,
    COALESCE(
        (au.raw_user_meta_data->>'created_by_admin_id')::UUID,
        (au.raw_user_meta_data->>'id_academia')::UUID
    ),
    TRUE,
    FALSE,
    au.created_at,
    NOW()
FROM auth.users au
WHERE au.raw_user_meta_data->>'role' = 'trainer'
  AND NOT EXISTS (
    SELECT 1 FROM public.users_personal up WHERE up.id = au.id
  )
  AND (au.raw_user_meta_data->>'id_academia') IS NOT NULL;


-- ============================================================
-- PASSO 4: CONFIRMAR resultado
-- ============================================================
SELECT 'Nutricionistas inseridos:' as info, COUNT(*) as total
FROM public.users_nutricionista
WHERE email_verified = TRUE
  AND created_at::date = CURRENT_DATE

UNION ALL

SELECT 'Personais inseridos:', COUNT(*)
FROM public.users_personal
WHERE email_verified = TRUE
  AND created_at::date = CURRENT_DATE;


-- ============================================================
-- PASSO 5: Verificar se ainda há órfãos
-- ============================================================
SELECT 
    'AINDA ÓRFÃOS (id_academia NULL - ação manual necessária):' as aviso,
    au.id,
    au.email,
    au.raw_user_meta_data->>'role' as role,
    au.raw_user_meta_data->>'name' as nome
FROM auth.users au
WHERE au.raw_user_meta_data->>'role' IN ('nutritionist', 'trainer')
  AND NOT EXISTS (
    SELECT 1 FROM public.users_nutricionista un WHERE un.id = au.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.users_personal up WHERE up.id = au.id
  );

NOTIFY pgrst, 'reload schema';
SELECT '✅ Reparo concluído! Nutricionistas e Personais recuperados.' as status;
