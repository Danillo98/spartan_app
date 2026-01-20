-- ============================================
-- SCRIPT DE MIGRAÇÃO - ATUALIZAR TABELA MEALS
-- ============================================
-- Este script adiciona as colunas necessárias para armazenar
-- informações detalhadas das refeições (alimentos e macros)
-- 
-- IMPORTANTE: Execute este script APENAS UMA VEZ no Supabase SQL Editor
-- ============================================

-- Verificar e adicionar colunas necessárias
DO $$ 
BEGIN
    -- Adicionar coluna foods (alimentos) se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'meals' AND column_name = 'foods'
    ) THEN
        ALTER TABLE meals ADD COLUMN foods TEXT;
        RAISE NOTICE 'Coluna foods adicionada com sucesso!';
    ELSE
        RAISE NOTICE 'Coluna foods já existe.';
    END IF;

    -- Adicionar coluna protein (proteína) se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'meals' AND column_name = 'protein'
    ) THEN
        ALTER TABLE meals ADD COLUMN protein INTEGER;
        RAISE NOTICE 'Coluna protein adicionada com sucesso!';
    ELSE
        RAISE NOTICE 'Coluna protein já existe.';
    END IF;

    -- Adicionar coluna carbs (carboidratos) se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'meals' AND column_name = 'carbs'
    ) THEN
        ALTER TABLE meals ADD COLUMN carbs INTEGER;
        RAISE NOTICE 'Coluna carbs adicionada com sucesso!';
    ELSE
        RAISE NOTICE 'Coluna carbs já existe.';
    END IF;

    -- Adicionar coluna fats (gorduras) se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'meals' AND column_name = 'fats'
    ) THEN
        ALTER TABLE meals ADD COLUMN fats INTEGER;
        RAISE NOTICE 'Coluna fats adicionada com sucesso!';
    ELSE
        RAISE NOTICE 'Coluna fats já existe.';
    END IF;

    -- Adicionar coluna instructions (instruções) se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'meals' AND column_name = 'instructions'
    ) THEN
        ALTER TABLE meals ADD COLUMN instructions TEXT;
        RAISE NOTICE 'Coluna instructions adicionada com sucesso!';
    ELSE
        RAISE NOTICE 'Coluna instructions já existe.';
    END IF;

    -- Tornar a coluna description opcional (pode ser NULL)
    ALTER TABLE meals ALTER COLUMN description DROP NOT NULL;
    RAISE NOTICE 'Coluna description agora é opcional.';

    -- Tornar a coluna meal_time opcional (pode ser NULL) e mudar tipo para TEXT
    -- Isso permite horários como "07:00" ao invés de TIME
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'meals' AND column_name = 'meal_time' AND data_type = 'time without time zone'
    ) THEN
        ALTER TABLE meals ALTER COLUMN meal_time TYPE TEXT USING meal_time::TEXT;
        ALTER TABLE meals ALTER COLUMN meal_time DROP NOT NULL;
        RAISE NOTICE 'Coluna meal_time convertida para TEXT e agora é opcional.';
    END IF;
END $$;

-- Migrar dados existentes de description para foods (se houver)
UPDATE meals 
SET foods = description 
WHERE foods IS NULL AND description IS NOT NULL;

-- ============================================
-- VERIFICAÇÃO FINAL
-- ============================================
-- Mostrar as colunas da tabela meals
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'meals'
ORDER BY ordinal_position;
