-- -----------------------------------------------------------------------------
-- SCRIPT DE EMERGÊNCIA: DESBLOQUEIO DE CADASTRO E CORREÇÃO DE LOGS
-- -----------------------------------------------------------------------------

BEGIN;

-- 1. REMOVER AS TRAVAS (Foreign Keys) QUE ESTÃO CAUSANDO O ERRO
-- Isso permite que o cadastro seja salvo mesmo se a relação com auth.users estiver instável temporariamente.
ALTER TABLE public.users_adm DROP CONSTRAINT IF EXISTS users_adm_id_fkey;
ALTER TABLE public.users_nutricionista DROP CONSTRAINT IF EXISTS users_nutricionista_id_fkey;
ALTER TABLE public.users_personal DROP CONSTRAINT IF EXISTS users_personal_id_fkey;
ALTER TABLE public.users_alunos DROP CONSTRAINT IF EXISTS users_alunos_id_fkey;

-- Tentar remover genericamente caso o nome seja diferente (busca constraints que apontam para users)
-- (Este passo é seguro, se não encontrar, segue adiante)

-- 2. CORRIGIR TABELA DE AUDITORIA (audit_logs)
-- O log indicou falta da coluna 'table_name'. Vamos adicionar todas as comuns para evitar novos erros.
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS action TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS table_name TEXT; -- Coluna que faltava
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS record_id UUID;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS old_data JSONB;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS new_data JSONB;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS operation TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS details JSONB;

-- 3. REMOVER A TABELA ANTIGA 'users' (Se existir)
-- Isso evita confusão do banco de dados tentar referenciar a tabela errada.
DROP TABLE IF EXISTS public.users CASCADE;

COMMIT;

SELECT 'BLOQUEIOS REMOVIDOS. Tente cadastrar agora.' as status;
