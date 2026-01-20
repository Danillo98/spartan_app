-- ============================================
-- CORREÇÕES FINAIS PARA TABELAS DE TREINO
-- Execute este script no Supabase SQL Editor
-- ============================================

-- 1. Adicionar coluna 'description' em workout_days (se não existir)
ALTER TABLE public.workout_days 
ADD COLUMN IF NOT EXISTS description TEXT;

-- 2. Adicionar coluna 'duration' em workout_exercises (se não existir)
ALTER TABLE public.workout_exercises 
ADD COLUMN IF NOT EXISTS duration TEXT;

-- 3. Verificar estrutura final
SELECT 
    'workout_days' as tabela,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'workout_days'
  AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 
    'workout_exercises' as tabela,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'workout_exercises'
  AND table_schema = 'public'
ORDER BY ordinal_position;
