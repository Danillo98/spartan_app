-- ========================================
-- MIGRAÇÃO CRÍTICA: CNPJ_ACADEMIA → ID_ACADEMIA
-- ========================================
-- Este script adiciona a coluna id_academia em todas as tabelas
-- e migra os dados existentes para usar o ID do admin como identificador único

-- 1. ADICIONAR COLUNA id_academia em todas as tabelas de usuários
-- ========================================

-- users_nutricionista
ALTER TABLE public.users_nutricionista 
ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id) ON DELETE CASCADE;

-- users_personal
ALTER TABLE public.users_personal 
ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id) ON DELETE CASCADE;

-- users_alunos
ALTER TABLE public.users_alunos 
ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id) ON DELETE CASCADE;

-- 2. POPULAR id_academia com base no cnpj_academia existente
-- ========================================

-- Nutricionistas
UPDATE public.users_nutricionista
SET id_academia = (
  SELECT id FROM public.users_adm 
  WHERE users_adm.cnpj_academia = users_nutricionista.cnpj_academia 
  LIMIT 1
)
WHERE id_academia IS NULL;

-- Personal Trainers
UPDATE public.users_personal
SET id_academia = (
  SELECT id FROM public.users_adm 
  WHERE users_adm.cnpj_academia = users_personal.cnpj_academia 
  LIMIT 1
)
WHERE id_academia IS NULL;

-- Alunos
UPDATE public.users_alunos
SET id_academia = (
  SELECT id FROM public.users_adm 
  WHERE users_adm.cnpj_academia = users_alunos.cnpj_academia 
  LIMIT 1
)
WHERE id_academia IS NULL;

-- 3. TORNAR id_academia NOT NULL (após popular)
-- ========================================

ALTER TABLE public.users_nutricionista 
ALTER COLUMN id_academia SET NOT NULL;

ALTER TABLE public.users_personal 
ALTER COLUMN id_academia SET NOT NULL;

ALTER TABLE public.users_alunos 
ALTER COLUMN id_academia SET NOT NULL;

-- 4. ADICIONAR id_academia nas tabelas de conteúdo
-- ========================================

-- Dietas
ALTER TABLE public.diets 
ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id) ON DELETE CASCADE;

UPDATE public.diets
SET id_academia = (
  SELECT id_academia FROM public.users_nutricionista 
  WHERE users_nutricionista.id = diets.nutritionist_id
)
WHERE id_academia IS NULL;

ALTER TABLE public.diets 
ALTER COLUMN id_academia SET NOT NULL;

-- Treinos
ALTER TABLE public.workouts 
ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id) ON DELETE CASCADE;

UPDATE public.workouts
SET id_academia = (
  SELECT id_academia FROM public.users_personal
  WHERE users_personal.id = workouts.personal_id
)
WHERE id_academia IS NULL;

ALTER TABLE public.workouts 
ALTER COLUMN id_academia SET NOT NULL;

-- Avisos
ALTER TABLE public.notices 
ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id) ON DELETE CASCADE;

UPDATE public.notices
SET id_academia = (
  SELECT id FROM public.users_adm 
  WHERE users_adm.cnpj_academia = notices.cnpj_academia 
  LIMIT 1
)
WHERE id_academia IS NULL;

ALTER TABLE public.notices 
ALTER COLUMN id_academia SET NOT NULL;

-- Avaliações Físicas
ALTER TABLE public.physical_assessments 
ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id) ON DELETE CASCADE;

UPDATE public.physical_assessments
SET id_academia = (
  SELECT id_academia FROM public.users_alunos 
  WHERE users_alunos.id = physical_assessments.student_id
)
WHERE id_academia IS NULL;

ALTER TABLE public.physical_assessments 
ALTER COLUMN id_academia SET NOT NULL;

-- Agendamentos
ALTER TABLE public.appointments 
ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id) ON DELETE CASCADE;

UPDATE public.appointments
SET id_academia = (
  SELECT id_academia FROM public.users_alunos 
  WHERE users_alunos.id = appointments.student_id
)
WHERE id_academia IS NULL;

ALTER TABLE public.appointments 
ALTER COLUMN id_academia SET NOT NULL;

-- 5. CRIAR ÍNDICES para performance
-- ========================================

CREATE INDEX IF NOT EXISTS idx_users_nutricionista_id_academia ON public.users_nutricionista(id_academia);
CREATE INDEX IF NOT EXISTS idx_users_personal_id_academia ON public.users_personal(id_academia);
CREATE INDEX IF NOT EXISTS idx_users_alunos_id_academia ON public.users_alunos(id_academia);
CREATE INDEX IF NOT EXISTS idx_diets_id_academia ON public.diets(id_academia);
CREATE INDEX IF NOT EXISTS idx_workouts_id_academia ON public.workouts(id_academia);
CREATE INDEX IF NOT EXISTS idx_notices_id_academia ON public.notices(id_academia);
CREATE INDEX IF NOT EXISTS idx_physical_assessments_id_academia ON public.physical_assessments(id_academia);
CREATE INDEX IF NOT EXISTS idx_appointments_id_academia ON public.appointments(id_academia);

-- 6. ATUALIZAR RLS POLICIES - USERS_NUTRICIONISTA
-- ========================================

DROP POLICY IF EXISTS "Nutricionistas podem ver próprio perfil" ON public.users_nutricionista;
CREATE POLICY "Nutricionistas podem ver próprio perfil" 
ON public.users_nutricionista FOR SELECT 
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admin pode ver nutricionistas da academia" ON public.users_nutricionista;
CREATE POLICY "Admin pode ver nutricionistas da academia" 
ON public.users_nutricionista FOR SELECT 
USING (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admin pode criar nutricionistas" ON public.users_nutricionista;
CREATE POLICY "Admin pode criar nutricionistas" 
ON public.users_nutricionista FOR INSERT 
WITH CHECK (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admin pode atualizar nutricionistas da academia" ON public.users_nutricionista;
CREATE POLICY "Admin pode atualizar nutricionistas da academia" 
ON public.users_nutricionista FOR UPDATE 
USING (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admin pode deletar nutricionistas da academia" ON public.users_nutricionista;
CREATE POLICY "Admin pode deletar nutricionistas da academia" 
ON public.users_nutricionista FOR DELETE 
USING (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

-- 7. ATUALIZAR RLS POLICIES - USERS_PERSONAL
-- ========================================

DROP POLICY IF EXISTS "Personal pode ver próprio perfil" ON public.users_personal;
CREATE POLICY "Personal pode ver próprio perfil" 
ON public.users_personal FOR SELECT 
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admin pode ver personals da academia" ON public.users_personal;
CREATE POLICY "Admin pode ver personals da academia" 
ON public.users_personal FOR SELECT 
USING (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admin pode criar personals" ON public.users_personal;
CREATE POLICY "Admin pode criar personals" 
ON public.users_personal FOR INSERT 
WITH CHECK (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admin pode atualizar personals da academia" ON public.users_personal;
CREATE POLICY "Admin pode atualizar personals da academia" 
ON public.users_personal FOR UPDATE 
USING (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admin pode deletar personals da academia" ON public.users_personal;
CREATE POLICY "Admin pode deletar personals da academia" 
ON public.users_personal FOR DELETE 
USING (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

-- 8. ATUALIZAR RLS POLICIES - USERS_ALUNOS
-- ========================================

DROP POLICY IF EXISTS "Aluno pode ver próprio perfil" ON public.users_alunos;
CREATE POLICY "Aluno pode ver próprio perfil" 
ON public.users_alunos FOR SELECT 
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admin pode ver alunos da academia" ON public.users_alunos;
CREATE POLICY "Admin pode ver alunos da academia" 
ON public.users_alunos FOR SELECT 
USING (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Nutricionista pode ver alunos da academia" ON public.users_alunos;
CREATE POLICY "Nutricionista pode ver alunos da academia" 
ON public.users_alunos FOR SELECT 
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Personal pode ver alunos da academia" ON public.users_alunos;
CREATE POLICY "Personal pode ver alunos da academia" 
ON public.users_alunos FOR SELECT 
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admin pode criar alunos" ON public.users_alunos;
CREATE POLICY "Admin pode criar alunos" 
ON public.users_alunos FOR INSERT 
WITH CHECK (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admin pode atualizar alunos da academia" ON public.users_alunos;
CREATE POLICY "Admin pode atualizar alunos da academia" 
ON public.users_alunos FOR UPDATE 
USING (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admin pode deletar alunos da academia" ON public.users_alunos;
CREATE POLICY "Admin pode deletar alunos da academia" 
ON public.users_alunos FOR DELETE 
USING (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

-- 9. ATUALIZAR RLS POLICIES - DIETS
-- ========================================

DROP POLICY IF EXISTS "Nutricionista pode ver dietas da academia" ON public.diets;
CREATE POLICY "Nutricionista pode ver dietas da academia" 
ON public.diets FOR SELECT 
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Nutricionista pode criar dietas" ON public.diets;
CREATE POLICY "Nutricionista pode criar dietas" 
ON public.diets FOR INSERT 
WITH CHECK (
  id_academia IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Nutricionista pode atualizar dietas da academia" ON public.diets;
CREATE POLICY "Nutricionista pode atualizar dietas da academia" 
ON public.diets FOR UPDATE 
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Nutricionista pode deletar dietas da academia" ON public.diets;
CREATE POLICY "Nutricionista pode deletar dietas da academia" 
ON public.diets FOR DELETE 
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Aluno pode ver próprias dietas" ON public.diets;
CREATE POLICY "Aluno pode ver próprias dietas" 
ON public.diets FOR SELECT 
USING (student_id = auth.uid());

-- 10. ATUALIZAR RLS POLICIES - WORKOUTS
-- ========================================

DROP POLICY IF EXISTS "Personal pode ver treinos da academia" ON public.workouts;
CREATE POLICY "Personal pode ver treinos da academia" 
ON public.workouts FOR SELECT 
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Personal pode criar treinos" ON public.workouts;
CREATE POLICY "Personal pode criar treinos" 
ON public.workouts FOR INSERT 
WITH CHECK (
  id_academia IN (
    SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Personal pode atualizar treinos da academia" ON public.workouts;
CREATE POLICY "Personal pode atualizar treinos da academia" 
ON public.workouts FOR UPDATE 
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Personal pode deletar treinos da academia" ON public.workouts;
CREATE POLICY "Personal pode deletar treinos da academia" 
ON public.workouts FOR DELETE 
USING (
  id_academia IN (
    SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Aluno pode ver próprios treinos" ON public.workouts;
CREATE POLICY "Aluno pode ver próprios treinos" 
ON public.workouts FOR SELECT 
USING (student_id = auth.uid());

-- 11. ATUALIZAR RLS POLICIES - NOTICES
-- ========================================

DROP POLICY IF EXISTS "Todos podem ver avisos da academia" ON public.notices;
CREATE POLICY "Todos podem ver avisos da academia" 
ON public.notices FOR SELECT 
USING (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
    UNION
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
    UNION
    SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
    UNION
    SELECT id_academia FROM public.users_alunos WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admin pode criar avisos" ON public.notices;
CREATE POLICY "Admin pode criar avisos" 
ON public.notices FOR INSERT 
WITH CHECK (
  id_academia IN (
    SELECT id FROM public.users_adm WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Nutricionista pode criar avisos" ON public.notices;
CREATE POLICY "Nutricionista pode criar avisos" 
ON public.notices FOR INSERT 
WITH CHECK (
  id_academia IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Personal pode criar avisos" ON public.notices;
CREATE POLICY "Personal pode criar avisos" 
ON public.notices FOR INSERT 
WITH CHECK (
  id_academia IN (
    SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Criador pode atualizar aviso" ON public.notices;
CREATE POLICY "Criador pode atualizar aviso" 
ON public.notices FOR UPDATE 
USING (created_by = auth.uid());

DROP POLICY IF EXISTS "Criador pode deletar aviso" ON public.notices;
CREATE POLICY "Criador pode deletar aviso" 
ON public.notices FOR DELETE 
USING (created_by = auth.uid());

-- 12. MENSAGEM DE SUCESSO
-- ========================================

SELECT 'Migração CNPJ_ACADEMIA → ID_ACADEMIA concluída com sucesso!' as status;
