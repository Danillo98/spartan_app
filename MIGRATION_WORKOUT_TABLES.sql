-- Adicionar colunas faltantes nas tabelas de treino

-- 1. Adicionar 'description' em workout_days
ALTER TABLE public.workout_days 
ADD COLUMN IF NOT EXISTS description TEXT;

-- 2. Adicionar 'duration' em workout_exercises (para tempo de execução)
ALTER TABLE public.workout_exercises 
ADD COLUMN IF NOT EXISTS duration TEXT;

-- 3. Atualizar a coluna day_id (caso tenha sido criada com nome errado)
-- Verificar se existe 'day_id' ou 'workout_day_id'
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'workout_exercises' 
        AND column_name = 'day_id'
    ) THEN
        ALTER TABLE public.workout_exercises 
        RENAME COLUMN workout_day_id TO day_id;
    END IF;
END $$;
