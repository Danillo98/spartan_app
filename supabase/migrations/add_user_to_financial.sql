-- Adicionar colunas para vincular usuário à transação
ALTER TABLE financial_transactions ADD COLUMN IF NOT EXISTS related_user_id UUID;
ALTER TABLE financial_transactions ADD COLUMN IF NOT EXISTS related_user_role TEXT; -- 'student', 'nutritionist', 'trainer'

-- Índices opcionais para busca futura por usuário
CREATE INDEX IF NOT EXISTS idx_financial_user ON financial_transactions(related_user_id);
