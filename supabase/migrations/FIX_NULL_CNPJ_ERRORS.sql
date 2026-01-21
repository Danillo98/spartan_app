-- ===============================================================
-- CORREÇÃO DE ERROS DE SQL E ESTRUTURA (VERSÃO ROBUSTA)
-- ===============================================================

-- 1. ADICIONAR COLUNA id_academia EM Transações Financeiras (Esquecido anteriormente)
ALTER TABLE public.financial_transactions 
ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id) ON DELETE CASCADE;

-- Tentar popular id_academia via related_user_id (se existir)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'financial_transactions' AND column_name = 'related_user_id') THEN
        UPDATE public.financial_transactions
        SET id_academia = (
            SELECT id_academia FROM public.users_alunos 
            WHERE users_alunos.id = financial_transactions.related_user_id
        )
        WHERE id_academia IS NULL;
    END IF;
END $$;

-- Popular restantes usando CNPJ antigo como fallback (apenas se a coluna cnpj_academia existir)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'financial_transactions' AND column_name = 'cnpj_academia') THEN
        UPDATE public.financial_transactions
        SET id_academia = (
          SELECT id FROM public.users_adm 
          WHERE users_adm.cnpj_academia = financial_transactions.cnpj_academia 
          LIMIT 1
        )
        WHERE id_academia IS NULL;
    END IF;
END $$;

-- 2. TORNAR cnpj_academia OPCIONAL (DROP NOT NULL)
-- Feito dentro de blocos DO para verificar se a coluna existe antes de alterar.
-- Isso evita erro "column does not exist".

DO $$
BEGIN
    -- users_nutricionista
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_nutricionista' AND column_name = 'cnpj_academia') THEN
        ALTER TABLE public.users_nutricionista ALTER COLUMN cnpj_academia DROP NOT NULL;
    END IF;

    -- users_personal
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_personal' AND column_name = 'cnpj_academia') THEN
        ALTER TABLE public.users_personal ALTER COLUMN cnpj_academia DROP NOT NULL;
    END IF;

    -- users_alunos
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_alunos' AND column_name = 'cnpj_academia') THEN
        ALTER TABLE public.users_alunos ALTER COLUMN cnpj_academia DROP NOT NULL;
    END IF;

    -- workouts (Corrigido: era training_sheets)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workouts' AND column_name = 'cnpj_academia') THEN
        ALTER TABLE public.workouts ALTER COLUMN cnpj_academia DROP NOT NULL;
    END IF;

    -- diets
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'diets' AND column_name = 'cnpj_academia') THEN
        ALTER TABLE public.diets ALTER COLUMN cnpj_academia DROP NOT NULL;
    END IF;

    -- financial_transactions
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'financial_transactions' AND column_name = 'cnpj_academia') THEN
        ALTER TABLE public.financial_transactions ALTER COLUMN cnpj_academia DROP NOT NULL;
    END IF;

    -- appointments
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'appointments' AND column_name = 'cnpj_academia') THEN
        ALTER TABLE public.appointments ALTER COLUMN cnpj_academia DROP NOT NULL;
    END IF;

    -- notices
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notices' AND column_name = 'cnpj_academia') THEN
        ALTER TABLE public.notices ALTER COLUMN cnpj_academia DROP NOT NULL;
    END IF;

    -- physical_assessments
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'physical_assessments' AND column_name = 'cnpj_academia') THEN
        ALTER TABLE public.physical_assessments ALTER COLUMN cnpj_academia DROP NOT NULL;
    END IF;
END $$;

SELECT 'Correções aplicadas com sucesso (Colunas inexistentes foram ignoradas).' as status;
