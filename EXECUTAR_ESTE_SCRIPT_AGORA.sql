-- ============================================
-- EXECUTE ESTE SCRIPT AGORA NO SUPABASE
-- Correção Final das Tabelas de Treino
-- ============================================

-- 1. Adicionar coluna 'description' em workout_days
ALTER TABLE public.workout_days 
ADD COLUMN IF NOT EXISTS description TEXT;

-- 2. Garantir que 'duration' existe em workout_exercises  
ALTER TABLE public.workout_exercises 
ADD COLUMN IF NOT EXISTS duration TEXT;

-- 3. Remover colunas desnecessárias
ALTER TABLE public.workout_exercises 
DROP COLUMN IF EXISTS technique CASCADE;

ALTER TABLE public.workout_exercises 
DROP COLUMN IF EXISTS notes CASCADE;

ALTER TABLE public.workout_exercises 
DROP COLUMN IF EXISTS video_url CASCADE;

-- 4. Verificar resultado
SELECT 'Colunas de workout_exercises:' as info;
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'workout_exercises' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Colunas de workout_days:' as info;
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'workout_days' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
