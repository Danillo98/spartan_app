-- ===============================================================
-- CORREÇÃO DE PERMISSÕES PARA AVISOS (NOTICES)
-- ===============================================================

-- Remover policies antigas que podem estar conflitando
DROP POLICY IF EXISTS "Users can update their own notices" ON public.notices;
DROP POLICY IF EXISTS "Nutricionista pode atualizar avisos" ON public.notices;
DROP POLICY IF EXISTS "Personal pode atualizar avisos" ON public.notices;
DROP POLICY IF EXISTS "Admin pode atualizar avisos" ON public.notices;

-- 1. VIEW (SELECT) - Mantendo a lógica de ver avisos da academia
CREATE POLICY "Users can view notices from their academy" 
ON public.notices FOR SELECT 
USING (
  -- Admin vê tudo da sua academia (ele é a academia)
  (auth.uid() = id_academia) 
  OR
  -- Users veem se pertencerem a academia do aviso
  (id_academia IN (
    SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
    UNION
    SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
    UNION
    SELECT id_academia FROM public.users_alunos WHERE id = auth.uid()
  ))
);

-- 2. CREATE (INSERT) - Mantendo lógica existente ou reforçando
DROP POLICY IF EXISTS "Users can insert notices" ON public.notices;
CREATE POLICY "Users can insert notices" 
ON public.notices FOR INSERT 
WITH CHECK (
  auth.uid() = created_by 
  AND
  id_academia IN (
      SELECT id FROM public.users_adm WHERE id = auth.uid()
      UNION
      SELECT id_academia FROM public.users_nutricionista WHERE id = auth.uid()
      UNION
      SELECT id_academia FROM public.users_personal WHERE id = auth.uid()
  )
);

-- 3. UPDATE (ATUALIZAR) - AQUI ESTAVA O PROBLEMA
-- Permitir que quem criou (created_by) possa atualizar, ou o Admin da academia
CREATE POLICY "Creator can update notices" 
ON public.notices FOR UPDATE 
USING (
  auth.uid() = created_by 
  OR 
  auth.uid() = id_academia -- Admin
);

-- 4. DELETE (DELETAR)
-- Permitir que quem criou (created_by) possa deletar, ou o Admin
DROP POLICY IF EXISTS "Creator can delete notices" ON public.notices;
CREATE POLICY "Creator can delete notices" 
ON public.notices FOR DELETE 
USING (
  auth.uid() = created_by 
  OR 
  auth.uid() = id_academia -- Admin
);


-- ===============================================================
-- ATUALIZAÇÃO DA RPC get_students_for_staff PARA USAR id_academia
-- ===============================================================

DROP FUNCTION IF EXISTS get_students_for_staff();

CREATE OR REPLACE FUNCTION get_students_for_staff()
RETURNS TABLE (
  id uuid,
  nome text,
  email text,
  telefone text,
  cnpj_academia text,
  payment_due_day int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_role text;
  v_id_academia uuid;
BEGIN
  v_user_id := auth.uid();
  
  -- 1. Verifica se chamador é Nutricionista
  SELECT 'nutritionist', id_academia INTO v_role, v_id_academia
  FROM public.users_nutricionista WHERE id = v_user_id;

  -- 2. Se não, verifica se é Personal
  IF v_role IS NULL THEN
    SELECT 'trainer', id_academia INTO v_role, v_id_academia
    FROM public.users_personal WHERE id = v_user_id;
  END IF;

  -- 3. Se não, verifica se é Admin
  IF v_role IS NULL THEN
    SELECT 'admin', id INTO v_role, v_id_academia
    FROM public.users_adm WHERE id = v_user_id;
  END IF;

  -- Se não encontrou role ou academia, retorna vazio
  IF v_id_academia IS NULL THEN
    RETURN;
  END IF;

  -- Retorna todos os alunos DA MESMA ACADEMIA
  RETURN QUERY
  SELECT 
    ua.id,
    ua.nome,
    ua.email,
    ua.telefone,
    ua.cnpj_academia,
    ua.payment_due_day,
    ua.created_at
  FROM public.users_alunos ua
  WHERE ua.id_academia = v_id_academia
  ORDER BY ua.nome;
END;
$$;

SELECT 'Permissões de avisos e RPC de alunos corrigidas!' as status;
