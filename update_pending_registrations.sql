-- Adicionar colunas faltantes para o Funil de Vendas na tabela existente

ALTER TABLE public.pending_registrations 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending_verification',
ADD COLUMN IF NOT EXISTS current_step INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS plan_price NUMERIC,
ADD COLUMN IF NOT EXISTS address_number TEXT,
ADD COLUMN IF NOT EXISTS address_neighborhood TEXT,
ADD COLUMN IF NOT EXISTS address_city TEXT,
ADD COLUMN IF NOT EXISTS address_state TEXT,
ADD COLUMN IF NOT EXISTS address_cep TEXT;

-- Adicionar constraint de validação de status se não existir
DO $$ BEGIN
    ALTER TABLE public.pending_registrations 
    ADD CONSTRAINT check_status CHECK (status IN ('pending_verification', 'verified', 'abandoned', 'converted'));
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Habilitar Realtime para esta tabela (caso não esteja)
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE public.pending_registrations;
COMMIT;
