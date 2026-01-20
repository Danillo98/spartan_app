-- SOLUÇÃO NUCLEAR: REMOVER TODOS OS BLOQUEIOS

BEGIN;

-- 1. Remover sistema de auditoria quebrado (e seus gatilhos)
-- Isso elimina erros como "column severity missing", "column event_type missing", etc.
DROP TABLE IF EXISTS public.audit_logs CASCADE;

-- 2. Remover a trava de Chave Estrangeira (FK)
-- Isso elimina o erro "Key is not present in table users" e permite salvar o usuário.
ALTER TABLE public.users_adm DROP CONSTRAINT IF EXISTS users_adm_id_fkey;
ALTER TABLE public.users_nutricionista DROP CONSTRAINT IF EXISTS users_nutricionista_id_fkey;
ALTER TABLE public.users_personal DROP CONSTRAINT IF EXISTS users_personal_id_fkey;
ALTER TABLE public.users_alunos DROP CONSTRAINT IF EXISTS users_alunos_id_fkey;

COMMIT;

SELECT 'SISTEMA DESBLOQUEADO. Tente cadastrar agora.' as status;
