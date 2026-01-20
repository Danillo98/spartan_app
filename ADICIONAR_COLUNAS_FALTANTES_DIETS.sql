-- =============================================================================
-- ADICIONAR COLUNAS NAME, TOTAL_CALORIES E START_DATE À TABELA DIETS
-- =============================================================================

-- Adicionar coluna name (nome da dieta)
ALTER TABLE public.diets 
ADD COLUMN IF NOT EXISTS name TEXT;

-- Adicionar coluna total_calories (calorias totais)
ALTER TABLE public.diets 
ADD COLUMN IF NOT EXISTS total_calories INTEGER;

-- Adicionar coluna start_date (data de início)
ALTER TABLE public.diets 
ADD COLUMN IF NOT EXISTS start_date DATE;

-- Adicionar coluna status (status da dieta)
ALTER TABLE public.diets 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

SELECT 'Colunas name, total_calories, start_date e status adicionadas com sucesso!' as status;
