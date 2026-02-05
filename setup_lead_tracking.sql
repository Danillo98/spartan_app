-- Migration para preparar tabelas para Funil de Vendas (Lead Tracking)

-- 1. Tabela de Registros Pendentes (Lead Tracking)
CREATE TABLE IF NOT EXISTS public.pending_registrations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    
    -- Dados Parciais (Preenchidos ao longo do fluxo)
    gym_name TEXT,
    cnpj TEXT,
    full_name TEXT, -- Se coletado
    
    -- Endereço
    address_cep TEXT,
    address_street TEXT,
    address_number TEXT,
    address_neighborhood TEXT,
    address_city TEXT,
    address_state TEXT,
    
    -- Plano
    selected_plan TEXT,
    plan_price NUMERIC,
    
    -- Controle de Funil
    current_step INT DEFAULT 1, -- 1: Contato, 2: Dados, 3: Senha/Termos, 4: Pagamento
    status TEXT DEFAULT 'pending_verification' CHECK (status IN ('pending_verification', 'verified', 'abandoned', 'converted')),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index para busca rápida por email
CREATE INDEX IF NOT EXISTS idx_pending_registrations_email ON public.pending_registrations(email);


-- 2. Tabela de Códigos de Verificação (Manual)
CREATE TABLE IF NOT EXISTS public.email_verification_codes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email TEXT NOT NULL REFERENCES public.pending_registrations(email) ON DELETE CASCADE,
    code TEXT NOT NULL, -- Pode ser um PIN de 6 dígitos ou um UUID token
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index para validação
CREATE INDEX IF NOT EXISTS idx_verification_codes_email_code ON public.email_verification_codes(email, code);


-- 3. Habilitar Realtime (Importante para o App ouvir a mudança de status)
ALTER PUBLICATION supabase_realtime ADD TABLE public.pending_registrations;

-- Comentário: Rodar este script no SQL Editor do Supabase dashboard.
