-- Adicionar colunas solicitadas
ALTER TABLE public.workout_days ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.workout_exercises ADD COLUMN IF NOT EXISTS duration TEXT;
