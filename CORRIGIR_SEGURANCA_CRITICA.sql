-- ============================================
-- SCRIPT DE CORREÇÃO DE SEGURANÇA CRÍTICA (V2)
-- ============================================
-- Correção: Ajustado para verificar Admins na tabela 'users_adm'
-- já que a tabela unificada 'public.users' não existe neste esquema.

-- 1. PROTEGER TRANSAÇÕES FINANCEIRAS
ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;

-- Remover policies antigas se existirem para evitar conflito/erro
DROP POLICY IF EXISTS "Admins total access financial" ON public.financial_transactions;

-- Apenas Admin (quem está na tabela users_adm) pode ver/editar
CREATE POLICY "Admins total access financial" ON public.financial_transactions
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.users_adm 
    WHERE users_adm.id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users_adm 
    WHERE users_adm.id = auth.uid()
  )
);

-- 2. PROTEGER CÓDIGOS DE VERIFICAÇÃO
ALTER TABLE public.email_verification_codes ENABLE ROW LEVEL SECURITY;
-- Sem políticas = Acesso bloqueado via API (Correto)

-- 3. PROTEGER TENTATIVAS DE LOGIN
ALTER TABLE public.login_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins view login attempts" ON public.login_attempts;

-- Apenas Admin vê histórico
CREATE POLICY "Admins view login attempts" ON public.login_attempts
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.users_adm 
    WHERE users_adm.id = auth.uid()
  )
);

-- 4. PROTEGER LOGS DE AUDITORIA
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins view all logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Users view own logs" ON public.audit_logs;

-- Admin vê tudo
CREATE POLICY "Admins view all logs" ON public.audit_logs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.users_adm 
    WHERE users_adm.id = auth.uid()
  )
);

-- Usuários comuns veem apenas seus próprios logs
-- (Isso não depende da tabela de usuários, apenas do ID na auth)
CREATE POLICY "Users view own logs" ON public.audit_logs
FOR SELECT
USING (
  user_id = auth.uid()
);

-- ============================================
-- CONFIRMAÇÃO
-- ============================================
DO $$
BEGIN
  RAISE NOTICE 'RLS Habilitado e Corrigido (Referência users_adm).';
END $$;
