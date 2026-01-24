-- SOLUCAO_DESBLOQUEIO_TOTAL_V2.sql
-- =============================================================================
-- REMOÇÃO CIRÚRGICA DE DEPENDÊNCIAS V2 (SEM ERRO DE COMPILAÇÃO)
-- =============================================================================

BEGIN;

-- 1. LIMPAR DEPENDÊNCIAS DE PERSONAL TRAINER (Treinos presos)
DO $$
DECLARE
    v_personal_id UUID;
BEGIN
    SELECT id INTO v_personal_id FROM public.users_personal WHERE email = 'canaltop98@gmail.com';

    IF v_personal_id IS NOT NULL THEN
        RAISE NOTICE 'Encontrado Personal fantasma. Removendo dependências...';
        UPDATE public.workouts SET personal_id = NULL WHERE personal_id = v_personal_id;
        DELETE FROM public.users_personal WHERE id = v_personal_id;
    END IF;
END $$;

-- 2. LIMPAR DEPENDÊNCIAS DE NUTRICIONISTA (Dietas presas)
DO $$
DECLARE
    v_nutri_id UUID;
BEGIN
    SELECT id INTO v_nutri_id FROM public.users_nutricionista WHERE email = 'canaltop98@gmail.com';

    IF v_nutri_id IS NOT NULL THEN
         RAISE NOTICE 'Encontrado Nutri fantasma. Removendo dependências...';
         UPDATE public.diets SET nutritionist_id = NULL WHERE nutritionist_id = v_nutri_id;
         DELETE FROM public.users_nutricionista WHERE id = v_nutri_id;
    END IF;
END $$;

-- 3. LIMPEZA FINAL GERAL
DELETE FROM public.users_alunos WHERE email = 'canaltop98@gmail.com';
DELETE FROM public.users_adm WHERE email = 'canaltop98@gmail.com';
DELETE FROM auth.users WHERE email = 'canaltop98@gmail.com';

COMMIT;

-- 4. CONFIRMAÇÃO
DO $$
BEGIN
  RAISE NOTICE '✅ Limpeza concluida. Email desbloqueado.';
END $$;
