-- CORREÇÃO CRÍTICA DE AUDITORIA
-- Corrige erro: column "target_table" of relation "audit_logs" does not exist

-- 1. Adicionar coluna target_table se não existir (para compatibilidade com triggers de security_hardening)
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS target_table TEXT;

-- 2. Garantir que outras colunas esperadas também existam
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS target_id UUID;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS details JSONB;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS action TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS user_id UUID;

-- 3. Sincronizar dados entre table_name (legado) e target_table (novo)
-- Isso garante que logs antigos sejam visíveis independente da coluna usada
UPDATE public.audit_logs 
SET target_table = table_name 
WHERE target_table IS NULL AND table_name IS NOT NULL;

-- 4. Opcional: Se table_name não existir, criar como alias de target_table
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS table_name TEXT;
UPDATE public.audit_logs 
SET table_name = target_table 
WHERE table_name IS NULL AND target_table IS NOT NULL;

-- 5. Atualizar a função de auditoria para ser mais resiliente
CREATE OR REPLACE FUNCTION process_audit_log() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.audit_logs (
        user_id, 
        action, 
        target_table, -- Usando target_table
        table_name,   -- E também table_name para garantir
        target_id, 
        record_id,    -- E record_id (usado em outros scripts)
        details
    )
    VALUES (
        auth.uid(),
        TG_OP,
        TG_TABLE_NAME,
        TG_TABLE_NAME, -- Duplicar para garantir compatibilidade
        CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
        CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
        jsonb_build_object('old_data', OLD, 'new_data', NEW)
    );
    RETURN NULL; -- Trigger AFTER não precisa retornar NEW
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Recriar Trigger para Transações Financeiras (onde o erro foi reportado)
DROP TRIGGER IF EXISTS audit_financial_transactions ON public.financial_transactions;
CREATE TRIGGER audit_financial_transactions
AFTER UPDATE OR DELETE ON public.financial_transactions
FOR EACH ROW EXECUTE FUNCTION process_audit_log();

-- 7. Grant permissões necessárias
GRANT ALL ON public.audit_logs TO postgres;
GRANT ALL ON public.audit_logs TO service_role;
GRANT SELECT, INSERT ON public.audit_logs TO authenticated;
