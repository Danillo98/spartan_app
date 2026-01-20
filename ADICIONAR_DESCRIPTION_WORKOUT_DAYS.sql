-- Adicionar coluna 'description' na tabela workout_days
ALTER TABLE public.workout_days 
ADD COLUMN IF NOT EXISTS description TEXT;
