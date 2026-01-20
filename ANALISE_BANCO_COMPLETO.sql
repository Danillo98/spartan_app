-- ============================================
-- ANÁLISE RÁPIDA - ESTRUTURA DAS TABELAS PRINCIPAIS
-- ============================================

-- 1. Estrutura da tabela USERS
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'users'
ORDER BY ordinal_position;

-- 2. Estrutura da tabela DIETS
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'diets'
ORDER BY ordinal_position;

-- 3. Estrutura da tabela WORKOUTS
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'workouts'
ORDER BY ordinal_position;

-- 4. Ver TODAS as políticas RLS existentes
SELECT 
    tablename,
    policyname,
    cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, cmd;
