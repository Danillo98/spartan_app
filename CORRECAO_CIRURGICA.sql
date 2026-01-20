-- CORREÇÃO CIRÚRGICA (Sem alterar gatilhos de sistema)

BEGIN;

-- 1. CORRIGIR AUDIT_LOGS
-- Adiciona colunas faltantes para que o sistema de log pare de reclamar e permite nulos.
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS event_type TEXT;
ALTER TABLE public.audit_logs ALTER COLUMN event_type DROP NOT NULL; -- Garante que não falhe se vier nulo
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS table_name TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS action TEXT;

-- 2. CORRIGIR VÍNCULOS (FKs)
-- Removemos a FK antiga e criamos a nova apontando para auth.users

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

SELECT 'Correção Cirúrgica Aplicada com Sucesso. Tente o cadastro novamente.' as status;
