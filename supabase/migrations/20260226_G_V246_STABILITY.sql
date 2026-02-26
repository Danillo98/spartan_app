-- ============================================
-- ARQUIVO DE MIGRAÇÃO v2.4.6
-- ============================================
-- Este arquivo contém o SQL acima para histórico.
ALTER TABLE public.users_alunos DROP COLUMN IF EXISTS grace_period CASCADE;
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS next_payment_due DATE;
NOTIFY pgrst, 'reload schema';
