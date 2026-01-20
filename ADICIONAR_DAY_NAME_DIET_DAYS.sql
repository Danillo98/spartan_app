-- ============================================
-- SCRIPT DE MIGRAÇÃO - EXECUTAR UMA ÚNICA VEZ
-- ============================================
-- Este script adiciona as colunas necessárias para a nova dinâmica
-- de dias da semana na tabela diet_days.
-- 
-- IMPORTANTE: Execute este script APENAS UMA VEZ no Supabase SQL Editor
-- ============================================

-- Verificar se a coluna day_name existe
DO $$ 
BEGIN
    -- Adicionar coluna day_name se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'diet_days' AND column_name = 'day_name'
    ) THEN
        ALTER TABLE diet_days ADD COLUMN day_name TEXT;
        RAISE NOTICE 'Coluna day_name adicionada com sucesso!';
    ELSE
        RAISE NOTICE 'Coluna day_name já existe.';
    END IF;

    -- Adicionar coluna total_calories se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'diet_days' AND column_name = 'total_calories'
    ) THEN
        ALTER TABLE diet_days ADD COLUMN total_calories INTEGER DEFAULT 0;
        RAISE NOTICE 'Coluna total_calories adicionada com sucesso!';
    ELSE
        RAISE NOTICE 'Coluna total_calories já existe.';
    END IF;
END $$;

-- Atualizar day_name para dias existentes que não têm nome
UPDATE diet_days 
SET day_name = 'Dia ' || day_number::TEXT 
WHERE day_name IS NULL OR day_name = '';

-- ============================================
-- VERIFICAÇÃO FINAL
-- ============================================
-- Mostrar as colunas da tabela diet_days
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'diet_days'
ORDER BY ordinal_position;
