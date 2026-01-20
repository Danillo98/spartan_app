-- ============================================
-- DIAGNÓSTICO - Verificar estrutura REAL das tabelas
-- Execute este script no Supabase SQL Editor
-- ============================================

-- 1. Ver TODAS as colunas da tabela workout_exercises
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'workout_exercises'
ORDER BY ordinal_position;

-- 2. Ver TODAS as colunas da tabela workout_days
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'workout_days'
ORDER BY ordinal_position;

-- 3. Ver dados de exemplo (se existirem)
SELECT * FROM public.workout_exercises LIMIT 1;
