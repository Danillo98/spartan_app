-- ==============================================================================
-- 🛡️ SPARTAN APP - SECURITY HARDENING SCRIPT (RLS & AUDIT)
-- ==============================================================================
-- Instruções: Rode este script no Editor SQL do Supabase.

-- ------------------------------------------------------------------------------
-- 1. BLINDAGEM DA TABELA 'NOTIFICATIONS' (RLS)
-- ------------------------------------------------------------------------------

-- Ativar RLS na tabela notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Política 1: Usuários só podem ler suas próprias notificações
CREATE POLICY "Users can view own notifications"
ON public.notifications
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
);

-- Política 2: Apenas Admins (ou Service Role) podem criar notificações
-- (Assumindo que admins estão na tabela users_adm)
CREATE POLICY "Admins can insert notifications"
ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users_adm
    WHERE id = auth.uid()
  )
);

-- Política 3: Usuários podem marcar suas notificações como lidas (Update)
CREATE POLICY "Users can update own notifications"
ON public.notifications
FOR UPDATE
TO authenticated
USING (
  user_id = auth.uid()
)
WITH CHECK (
  user_id = auth.uid()
);

-- ------------------------------------------------------------------------------
-- 2. SISTEMA DE AUDITORIA (AUDIT LOGS)
-- ------------------------------------------------------------------------------

-- Criar tabela de Logs de Auditoria
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id), -- Quem fez a ação
    action TEXT NOT NULL,                  -- Ex: 'UPDATE_PASSWORD', 'DELETE_USER'
    target_table TEXT NOT NULL,            -- Tabela afetada
    target_id UUID,                        -- ID do registro afetado
    details JSONB,                         -- Detalhes (ex: valor antigo -> novo)
    ip_address TEXT,                       -- IP (se disponível via trigger)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Proteger a tabela de logs (Ninguém pode apagar logs, nem admin)
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view audit logs"
ON public.audit_logs
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users_adm
    WHERE id = auth.uid()
  )
);

-- Ninguém pode inserir/atualizar/deletar logs manualmente (Apenas o sistema/triggers)
-- (Não criamos policies de INSERT/UPDATE/DELETE para 'authenticated', bloqueando tudo por padrão)

-- ------------------------------------------------------------------------------
-- 3. GATILHO PARA AUDITORIA DE SENHA (Exemplo Prático)
-- ------------------------------------------------------------------------------
-- Como a mudança de senha é feita via RPC 'admin_update_password', vamos adicionar o log lá.
-- Você deve ATUALIZAR sua função 'admin_update_password' com este conteúdo:

/*
CREATE OR REPLACE FUNCTION admin_update_password(target_user_id UUID, new_password TEXT)
RETURNS VOID AS $$
DECLARE
  operator_id UUID;
BEGIN
  -- Identificar quem está chamando (O Admin)
  operator_id := auth.uid();

  -- 1. Verificar se quem chama é realmente um admin
  IF NOT EXISTS (SELECT 1 FROM public.users_adm WHERE id = operator_id) THEN
    RAISE EXCEPTION 'Acesso negado: Apenas administradores podem alterar senhas.';
  END IF;

  -- 2. Atualizar a senha no auth.users
  UPDATE auth.users
  SET encrypted_password = crypt(new_password, gen_salt('bf'))
  WHERE id = target_user_id;

  -- 3. Registrar no Log de Auditoria
  INSERT INTO public.audit_logs (user_id, action, target_table, target_id, details)
  VALUES (
    operator_id, 
    'ADMIN_UPDATE_PASSWORD', 
    'auth.users', 
    target_user_id, 
    jsonb_build_object('timestamp', now())
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
*/

-- ------------------------------------------------------------------------------
-- 4. GATILHO GENÉRICO PARA MUDANÇAS CRÍTICAS (Ex: Dados Financeiros)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION process_audit_log() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.audit_logs (user_id, action, target_table, target_id, details)
    VALUES (
        auth.uid(),
        TG_OP,             -- INSERT, UPDATE, DELETE
        TG_TABLE_NAME,
        NEW.id,            -- ID do registro
        jsonb_build_object('old_data', OLD, 'new_data', NEW)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Aplicar auditoria na tabela Financeira (Exemplo)
DROP TRIGGER IF EXISTS audit_financial_transactions ON public.financial_transactions;
CREATE TRIGGER audit_financial_transactions
AFTER UPDATE OR DELETE ON public.financial_transactions
FOR EACH ROW EXECUTE FUNCTION process_audit_log();

-- ------------------------------------------------------------------------------
-- FIM DO SCRIPT
-- ==============================================================================
