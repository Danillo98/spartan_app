-- -----------------------------------------------------------------------------
-- SCRIPT DE CORREÇÃO CRÍTICA DE CHAVES ESTRANGEIRAS E AUDITORIA
-- -----------------------------------------------------------------------------
-- Este script corrige o erro onde as tabelas de usuários (users_adm, etc)
-- estão referenciando a tabela 'public.users' (incorreta/antiga) em vez de 'auth.users'.
-- Também corrige a tabela de logs.

BEGIN;

-- 1. Corrigir users_adm
ALTER TABLE public.users_adm DROP CONSTRAINT IF EXISTS users_adm_id_fkey;
-- Remove qualquer outra constraint que possa estar errada pelo nome
ALTER TABLE public.users_adm DROP CONSTRAINT IF EXISTS users_adm_id_fkey1; 
ALTER TABLE public.users_adm ADD CONSTRAINT users_adm_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 2. Corrigir users_nutricionista
ALTER TABLE public.users_nutricionista DROP CONSTRAINT IF EXISTS users_nutricionista_id_fkey;
ALTER TABLE public.users_nutricionista ADD CONSTRAINT users_nutricionista_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 3. Corrigir users_personal
ALTER TABLE public.users_personal DROP CONSTRAINT IF EXISTS users_personal_id_fkey;
ALTER TABLE public.users_personal ADD CONSTRAINT users_personal_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 4. Corrigir users_alunos
ALTER TABLE public.users_alunos DROP CONSTRAINT IF EXISTS users_alunos_id_fkey;
ALTER TABLE public.users_alunos ADD CONSTRAINT users_alunos_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 5. Corrigir audit_logs (adicionar coluna action se faltar)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    action TEXT,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tentar adicionar a coluna caso a tabela exista mas sem ela
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='audit_logs' AND column_name='action') THEN
        ALTER TABLE public.audit_logs ADD COLUMN action TEXT;
    END IF;
END $$;

COMMIT;

-- Confirmação
SELECT 'Correção de FKs e Audit Logs aplicada com sucesso.' as status;
