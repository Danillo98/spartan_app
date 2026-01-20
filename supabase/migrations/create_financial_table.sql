-- Tabela de Transações Financeiras
CREATE TABLE IF NOT EXISTS financial_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cnpj_academia TEXT NOT NULL,
    description TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL, -- Valor com 2 casas decimais
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')), -- income = entrada, expense = saída
    category TEXT, -- Para despesas: 'fixed' (Fixo), 'variable' (Variável). Para entradas: 'tuition' (Mensalidade), 'other' (Outros)
    transaction_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_financial_cnpj ON financial_transactions(cnpj_academia);
CREATE INDEX IF NOT EXISTS idx_financial_date ON financial_transactions(transaction_date);
