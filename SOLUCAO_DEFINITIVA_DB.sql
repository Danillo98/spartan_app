-- =============================================================================
-- SOLUÇÃO DEFINITIVA: CORREÇÃO ESTRUTURAL DO BANCO DE DADOS
-- =============================================================================

BEGIN;

-- 1. ELIMINAR AMBIGUIDADE (Remover tabela antiga definitivamente)
-- Isso garante que nenhuma FK possa apontar acidentalmente para esta tabela.
DROP TABLE IF EXISTS public.users CASCADE;

-- 2. CORRIGIR TABELA DE AUDITORIA (audit_logs)
-- Adiciona todas as colunas necessárias para garantir que os triggers de log não falhem.
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Adicionar colunas se não existirem (Safe Alter)
DO $$
BEGIN
    ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS user_id UUID;
    ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS action TEXT;
    ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS table_name TEXT;
    ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS record_id UUID;
    ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS old_data JSONB;
    ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS new_data JSONB;
    ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS operation TEXT;
    ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS details JSONB;
EXCEPTION
    WHEN duplicate_column THEN NULL;
END $$;

-- 3. RECRIAR CHAVES ESTRANGEIRAS (Apontando EXPLICITAMENTE para auth.users)
-- Removemos as antigas e criamos novas forçando auth.users.

-- Users ADM
ALTER TABLE public.users_adm DROP CONSTRAINT IF EXISTS users_adm_id_fkey;
ALTER TABLE public.users_adm ADD CONSTRAINT users_adm_id_fkey 
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Users Nutricionista
ALTER TABLE public.users_nutricionista DROP CONSTRAINT IF EXISTS users_nutricionista_id_fkey;
ALTER TABLE public.users_nutricionista ADD CONSTRAINT users_nutricionista_id_fkey 
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Users Personal
ALTER TABLE public.users_personal DROP CONSTRAINT IF EXISTS users_personal_id_fkey;
ALTER TABLE public.users_personal ADD CONSTRAINT users_personal_id_fkey 
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Users Alunos
ALTER TABLE public.users_alunos DROP CONSTRAINT IF EXISTS users_alunos_id_fkey;
ALTER TABLE public.users_alunos ADD CONSTRAINT users_alunos_id_fkey 
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

COMMIT;

SELECT 'Solução Definitiva Aplicada: Tabela antiga removida, FKs corrigidas para auth.users e Audit Logs reparado.' as status;
