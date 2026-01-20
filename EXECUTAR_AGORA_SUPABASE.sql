-- ============================================
-- SCRIPT DEFINITIVO - CORREÇÃO TABELAS TREINO
-- Execute este script COMPLETO no Supabase SQL Editor
-- ============================================

-- 1. Adicionar coluna 'description' em workout_days
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'workout_days' 
        AND column_name = 'description'
    ) THEN
        ALTER TABLE public.workout_days ADD COLUMN description TEXT;
        RAISE NOTICE 'Coluna description adicionada em workout_days';
    ELSE
        RAISE NOTICE 'Coluna description já existe em workout_days';
    END IF;
END $$;

-- 2. Adicionar coluna 'duration' em workout_exercises
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'workout_exercises' 
        AND column_name = 'duration'
    ) THEN
        ALTER TABLE public.workout_exercises ADD COLUMN duration TEXT;
        RAISE NOTICE 'Coluna duration adicionada em workout_exercises';
    ELSE
        RAISE NOTICE 'Coluna duration já existe em workout_exercises';
    END IF;
END $$;

-- 3. Verificar estrutura final das tabelas
SELECT 
    'workout_days' as tabela,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'workout_days'
ORDER BY ordinal_position;

SELECT 
    'workout_exercises' as tabela,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'workout_exercises'
ORDER BY ordinal_position;

-- 4. Verificar dados existentes
SELECT 
    'Fichas cadastradas' as info,
    COUNT(*) as total
FROM public.workouts;

SELECT 
    'Dias cadastrados' as info,
    COUNT(*) as total
FROM public.workout_days;

SELECT 
    'Exercícios cadastrados' as info,
    COUNT(*) as total
FROM public.workout_exercises;
