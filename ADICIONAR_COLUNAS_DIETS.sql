-- =============================================================================
-- ADICIONAR COLUNAS DESCRIPTION, END_DATE E GOAL À TABELA DIETS
-- =============================================================================

-- Adicionar coluna description (descrição da dieta)
ALTER TABLE public.diets 
ADD COLUMN IF NOT EXISTS description TEXT;

-- Adicionar coluna end_date (data de término da dieta)
ALTER TABLE public.diets 
ADD COLUMN IF NOT EXISTS end_date DATE;

-- Adicionar coluna goal (objetivo da dieta)
ALTER TABLE public.diets 
ADD COLUMN IF NOT EXISTS goal TEXT;

SELECT 'Colunas description, end_date e goal adicionadas com sucesso!' as status;
