-- LIMPEZA_ESPECIFICA_EMAIL.sql
-- =============================================================================
-- SCRIPT DE REMOÇÃO FORÇADA DE EMAIL BLOQUEADO
-- =============================================================================

BEGIN;

-- 1. Remover de todas as tabelas públicas (Case Insensitive)
-- Isso garante que o email esteja 100% livre.

DELETE FROM public.users_nutricionista 
WHERE email ILIKE 'canaltop98@gmail.com';

DELETE FROM public.users_personal 
WHERE email ILIKE 'canaltop98@gmail.com';

DELETE FROM public.users_alunos 
WHERE email ILIKE 'canaltop98@gmail.com';

DELETE FROM public.users_adm 
WHERE email ILIKE 'canaltop98@gmail.com';

-- 2. Remover também do Auth (apenas por precaução, se existir em estado inválido)
DELETE FROM auth.users 
WHERE email ILIKE 'canaltop98@gmail.com';

COMMIT;

DO $$
BEGIN
  RAISE NOTICE '✅ Limpeza específica para canaltop98@gmail.com realizada.';
END $$;
