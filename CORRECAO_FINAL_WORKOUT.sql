-- ============================================
-- CORREÇÃO FINAL COMPLETA - TABELAS DE TREINO
-- Execute este script COMPLETO no Supabase SQL Editor
-- ============================================

-- 1. Adicionar coluna 'description' em workout_days
ALTER TABLE public.workout_days 
ADD COLUMN IF NOT EXISTS description TEXT;

-- 2. Garantir que 'duration' existe em workout_exercises
ALTER TABLE public.workout_exercises 
ADD COLUMN IF NOT EXISTS duration TEXT;

-- 3. Remover colunas desnecessárias de workout_exercises
ALTER TABLE public.workout_exercises 
DROP COLUMN IF EXISTS technique CASCADE;

ALTER TABLE public.workout_exercises 
DROP COLUMN IF EXISTS notes CASCADE;

ALTER TABLE public.workout_exercises 
DROP COLUMN IF EXISTS video_url CASCADE;

-- 4. Verificar estrutura final
SELECT 
    'workout_exercises' as tabela,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'workout_exercises' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 
    'workout_days' as tabela,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'workout_days' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
