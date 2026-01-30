-- FIX 1: RLS for Notices (Segmentation)
-- Ensure that if target_user_ids is set, only those users can see it, OR if it is empty/null, follow target_role.
-- This replaces/overrides previous logic if possible, or we just ensure a new stricter policy.
-- Since we cannot easily drop specific policies without knowing names, we will DROP ALL policies on notices and recreate.

ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Notices visibility" ON public.notices;
DROP POLICY IF EXISTS "Users can view notices" ON public.notices;
DROP POLICY IF EXISTS "Admins manage notices" ON public.notices;
DROP POLICY IF EXISTS "Author manage notices" ON public.notices;

-- 1. VIEW POLICY
CREATE POLICY "Users can view notices"
ON public.notices
FOR SELECT
USING (
  id_academia = (
    -- Try to match academy from one of the user tables
    COALESCE(
      (SELECT id_academia FROM public.users_adm WHERE id = auth.uid()),
      (SELECT id_academia FROM public.users_alunos WHERE id = auth.uid()),
      (SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()),
      (SELECT id_academia FROM public.users_personal WHERE id = auth.uid())
    )
  )
  AND
  (
    -- 1. Admin sees all
    (EXISTS (SELECT 1 FROM public.users_adm WHERE id = auth.uid()))
    OR
    -- 2. Author sees their own
    (created_by = auth.uid())
    OR
    -- 3. Targeted Users logic
    (
      -- Must match Role
      (
        target_role = 'all' 
        OR 
        (target_role = 'student' AND EXISTS (SELECT 1 FROM public.users_alunos WHERE id = auth.uid()))
        OR
        (target_role = 'nutritionist' AND EXISTS (SELECT 1 FROM public.users_nutricionista WHERE id = auth.uid()))
        OR
        (target_role = 'trainer' AND EXISTS (SELECT 1 FROM public.users_personal WHERE id = auth.uid()))
      )
      AND
      (
        -- AND must be in target_user_ids IF it is present and not empty
        target_user_ids IS NULL 
        OR 
        jsonb_array_length(target_user_ids) = 0
        OR 
        target_user_ids @> to_jsonb(auth.uid()::text)
      )
    )
  )
);

-- 2. INSERT/UPDATE/DELETE (Admins + Authors)
CREATE POLICY "Admins and Authors manage notices"
ON public.notices
FOR ALL
USING (
  (EXISTS (SELECT 1 FROM public.users_adm WHERE id = auth.uid()))
  OR
  (created_by = auth.uid())
);


-- FIX 2: RLS for Workouts (Personal Trainer editing name)
-- Ensure Personal can UPDATE their workouts.

DROP POLICY IF EXISTS "Personal update workouts" ON public.workouts;

CREATE POLICY "Personal can update own workouts"
ON public.workouts
FOR UPDATE
USING (
  auth.uid() = personal_id
);

-- Ensure Personal can DELETE
DROP POLICY IF EXISTS "Personal delete workouts" ON public.workouts;
CREATE POLICY "Personal can delete own workouts"
ON public.workouts
FOR DELETE
USING (
  auth.uid() = personal_id
);


-- FIX 3: RLS for Workout Days/Exercises (Just to be safe)
ALTER TABLE public.workout_days ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Personal manage workout days"
ON public.workout_days
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.workouts 
    WHERE workouts.id = workout_days.workout_id 
    AND workouts.personal_id = auth.uid()
  )
);

ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Personal manage workout exercises"
ON public.workout_exercises
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.workout_days
    JOIN public.workouts ON workouts.id = workout_days.workout_id
    WHERE workout_days.id = workout_exercises.day_id
    AND workouts.personal_id = auth.uid()
  )
);
