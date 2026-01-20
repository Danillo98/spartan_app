-- ============================================
-- SCRIPT PARA MÓDULO DE TREINOS (PERSONAL)
-- VERSÃO FINAL: ADAPTADA PARA TABELAS SEPARADAS
-- ============================================

-- Limpeza preventiva
DROP TABLE IF EXISTS public.workout_exercises CASCADE;
DROP TABLE IF EXISTS public.workout_days CASCADE;
DROP TABLE IF EXISTS public.workouts CASCADE;

-- 1. TABELA DE FICHAS DE TREINO (WORKOUTS)
CREATE TABLE public.workouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  personal_id UUID NOT NULL REFERENCES public.users_personal(id), -- ✅ Vincula à tabela de Personais
  student_id UUID NOT NULL REFERENCES public.users_alunos(id),    -- ✅ Vincula à tabela de Alunos
  name TEXT NOT NULL,
  description TEXT,
  goal TEXT,
  difficulty_level TEXT,
  start_date DATE,
  end_date DATE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_workouts_personal ON public.workouts(personal_id);
CREATE INDEX idx_workouts_student ON public.workouts(student_id);

-- 2. TABELA DE DIAS DE TREINO (WORKOUT DAYS)
CREATE TABLE public.workout_days (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id UUID NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
  day_name TEXT NOT NULL, 
  day_letter CHAR(1),
  day_number INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_workout_days_workout ON public.workout_days(workout_id);

-- 3. TABELA DE EXERCÍCIOS DO TREINO (WORKOUT EXERCISES)
CREATE TABLE public.workout_exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_day_id UUID NOT NULL REFERENCES public.workout_days(id) ON DELETE CASCADE,
  exercise_name TEXT NOT NULL,
  muscle_group TEXT,
  sets INTEGER NOT NULL,
  reps TEXT NOT NULL,
  weight_kg INTEGER,
  rest_seconds INTEGER,
  technique TEXT,
  notes TEXT,
  video_url TEXT,
  order_index INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_workout_exercises_day ON public.workout_exercises(workout_day_id);

-- 4. POLÍTICAS DE SEGURANÇA (RLS)

ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;

-- Políticas para WORKOUTS
CREATE POLICY "Personal gerencia seus treinos" ON public.workouts
  FOR ALL
  USING (
    -- O usuário logado deve ser o personal dono do treino
    auth.uid() = personal_id
    AND EXISTS (SELECT 1 FROM public.users_personal WHERE id = auth.uid())
  );

CREATE POLICY "Aluno vê seus treinos" ON public.workouts
  FOR SELECT
  USING (
    -- O usuário logado deve ser o aluno do treino
    auth.uid() = student_id
    AND EXISTS (SELECT 1 FROM public.users_alunos WHERE id = auth.uid())
  );

CREATE POLICY "Admin total acesso" ON public.workouts
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.users_adm WHERE id = auth.uid())
  );

-- Políticas para WORKOUT DAYS
CREATE POLICY "Acesso a workout_days via workout" ON public.workout_days
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.workouts w 
      WHERE w.id = public.workout_days.workout_id 
      AND (
        w.personal_id = auth.uid() 
        OR w.student_id = auth.uid() 
        OR EXISTS (SELECT 1 FROM public.users_adm WHERE id = auth.uid())
      )
    )
  );

-- Políticas para WORKOUT EXERCISES
CREATE POLICY "Acesso a workout_exercises via day" ON public.workout_exercises
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.workout_days wd
      JOIN public.workouts w ON w.id = wd.workout_id
      WHERE wd.id = public.workout_exercises.workout_day_id
      AND (
        w.personal_id = auth.uid() 
        OR w.student_id = auth.uid() 
        OR EXISTS (SELECT 1 FROM public.users_adm WHERE id = auth.uid())
      )
    )
  );

-- Permissões
GRANT ALL ON public.workouts TO authenticated;
GRANT ALL ON public.workout_days TO authenticated;
GRANT ALL ON public.workout_exercises TO authenticated;
