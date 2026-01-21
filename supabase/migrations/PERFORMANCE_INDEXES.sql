-- Performance Optimization: Indexes for id_academia and Foreign Keys
-- Updated to be robust and skip non-existent columns via DO blocks.

-- 1. Indexes on id_academia (Critical for RLS and Filtering)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_nutricionista' AND column_name = 'id_academia') THEN
        CREATE INDEX IF NOT EXISTS idx_users_nutricionista_id_academia ON public.users_nutricionista(id_academia);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_personal' AND column_name = 'id_academia') THEN
        CREATE INDEX IF NOT EXISTS idx_users_personal_id_academia ON public.users_personal(id_academia);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_alunos' AND column_name = 'id_academia') THEN
        CREATE INDEX IF NOT EXISTS idx_users_alunos_id_academia ON public.users_alunos(id_academia);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workouts' AND column_name = 'id_academia') THEN
        CREATE INDEX IF NOT EXISTS idx_workouts_id_academia ON public.workouts(id_academia);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'diets' AND column_name = 'id_academia') THEN
        CREATE INDEX IF NOT EXISTS idx_diets_id_academia ON public.diets(id_academia);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'physical_assessments' AND column_name = 'id_academia') THEN
        CREATE INDEX IF NOT EXISTS idx_physical_assessments_id_academia ON public.physical_assessments(id_academia);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notices' AND column_name = 'id_academia') THEN
        CREATE INDEX IF NOT EXISTS idx_notices_id_academia ON public.notices(id_academia);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'financial_transactions' AND column_name = 'id_academia') THEN
        CREATE INDEX IF NOT EXISTS idx_financial_transactions_id_academia ON public.financial_transactions(id_academia);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'appointments' AND column_name = 'id_academia') THEN
        CREATE INDEX IF NOT EXISTS idx_appointments_id_academia ON public.appointments(id_academia);
    END IF;
END $$;

-- 2. Indexes on Foreign Keys (Join Performance)

-- Workouts
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workouts' AND column_name = 'student_id') THEN
        CREATE INDEX IF NOT EXISTS idx_workouts_student_id ON public.workouts(student_id);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workouts' AND column_name = 'personal_id') THEN
        CREATE INDEX IF NOT EXISTS idx_workouts_personal_id ON public.workouts(personal_id);
    END IF;
END $$;

-- Diets
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'diets' AND column_name = 'student_id') THEN
        CREATE INDEX IF NOT EXISTS idx_diets_student_id ON public.diets(student_id);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'diets' AND column_name = 'nutritionist_id') THEN
        CREATE INDEX IF NOT EXISTS idx_diets_nutritionist_id ON public.diets(nutritionist_id);
    END IF;
END $$;

-- Physical Assessments
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'physical_assessments' AND column_name = 'student_id') THEN
        CREATE INDEX IF NOT EXISTS idx_physical_assessments_student_id ON public.physical_assessments(student_id);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'physical_assessments' AND column_name = 'nutritionist_id') THEN
        CREATE INDEX IF NOT EXISTS idx_physical_assessments_nutritionist_id ON public.physical_assessments(nutritionist_id);
    END IF;
END $$;

-- Appointments (CORRIGIDO: Removido index invalido de nutritionist_id)
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'appointments' AND column_name = 'student_id') THEN
        CREATE INDEX IF NOT EXISTS idx_appointments_student_id ON public.appointments(student_id);
    END IF;
    -- appointments usa 'professional_ids' (array), ignorando index simples de nutritionist_id que não existe.
END $$;


-- 3. Indexes on specific filters

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notices' AND column_name = 'target_student_id') THEN
        CREATE INDEX IF NOT EXISTS idx_notices_target_student_id ON public.notices(target_student_id);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'financial_transactions' AND column_name = 'related_user_id') THEN
        CREATE INDEX IF NOT EXISTS idx_financial_transactions_related_user_id ON public.financial_transactions(related_user_id);
    END IF;
END $$;

SELECT 'Índices de performance criados com sucesso (seguro).' as status;
