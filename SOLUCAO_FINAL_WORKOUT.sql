-- ============================================
-- SOLUÇÃO FINAL - NÃO PRECISA RENOMEAR
-- A coluna JÁ SE CHAMA workout_day_id
-- Apenas garantir que as outras colunas existam
-- ============================================

-- 1. Adicionar coluna 'description' em workout_days (se não existir)
ALTER TABLE public.workout_days 
ADD COLUMN IF NOT EXISTS description TEXT;

-- 2. Adicionar coluna 'duration' em workout_exercises (se não existir)
ALTER TABLE public.workout_exercises 
ADD COLUMN IF NOT EXISTS duration TEXT;

-- 3. VERIFICAR estrutura da tabela workout_exercises
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'workout_exercises' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Resultado esperado: deve mostrar 'workout_day_id' (NÃO 'day_id')
