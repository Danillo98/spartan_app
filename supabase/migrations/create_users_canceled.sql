-- ============================================
-- TABELA DE HISTÓRICO DE USUÁRIOS CANCELADOS
-- ============================================

CREATE TABLE IF NOT EXISTS public.users_canceled (
    original_id UUID PRIMARY KEY, -- ID original do usuário para referência
    nome TEXT,
    email TEXT,
    telefone TEXT,
    cnpj_academia TEXT,
    cpf TEXT,
    academia TEXT,
    endereco TEXT,
    plano_mensal TEXT,
    assinatura_iniciada TIMESTAMP WITH TIME ZONE,
    assinatura_expirada TIMESTAMP WITH TIME ZONE,
    stripe_customer_id TEXT,
    
    -- Metadados do cancelamento
    cancelado_em TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    motivo_cancelamento TEXT
);

-- Permissões (Segurança)
ALTER TABLE public.users_canceled ENABLE ROW LEVEL SECURITY;

-- Permitir acesso total apenas para Service Role (Backend/Edge Functions)
-- O usuário final não deve ter acesso a essa tabela
DROP POLICY IF EXISTS "Service Role Full Access" ON public.users_canceled;
CREATE POLICY "Service Role Full Access" ON public.users_canceled
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
