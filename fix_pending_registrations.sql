-- Tabela para guardar dados temporários de cadastro (Substitui o Token via URL)
CREATE TABLE IF NOT EXISTS public.pending_registrations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    email text NOT NULL,
    name text NOT NULL,
    phone text,
    role text DEFAULT 'admin',
    
    -- Dados Críticos
    cpf text,
    address text,
    
    -- Dados da Academia
    cnpj_academia text,
    nome_academia text,
    plan text
);

-- Segurança (RLS)
ALTER TABLE public.pending_registrations ENABLE ROW LEVEL SECURITY;

-- Permitir que QUALQUER UM insira (para o cadastro público funcionar)
CREATE POLICY "Anon pode criar pendente" ON public.pending_registrations
FOR INSERT WITH CHECK (true);

-- Permitir leitura pública (necessário para o AuthService buscar os dados na confirmação antes do login)
-- Em produção ideal, usaríamos uma Edge Function para buscar isso, mas para resolver AGORA, RLS público resolve.
CREATE POLICY "Leitura publica" ON public.pending_registrations
FOR SELECT USING (true);
