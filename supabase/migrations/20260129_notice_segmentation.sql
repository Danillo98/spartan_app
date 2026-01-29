-- MELHORIA NO SISTEMA DE AVISOS (SEGMENTAÇÃO)
-- Permite enviar avisos para grupos específicos (Nutris, Personais, Alunos) ou indivíduos de qualquer grupo.

-- 1. Adicionar novas colunas
ALTER TABLE public.notices 
ADD COLUMN IF NOT EXISTS target_role text DEFAULT 'all', -- 'all', 'student', 'nutritionist', 'trainer'
ADD COLUMN IF NOT EXISTS target_user_id uuid; -- ID específico do usuário alvo (opcional)

-- 2. Migrar dados existentes (Retrocompatibilidade)
-- Se tinha target_student_id, move para target_user_id e define role como 'student'
UPDATE public.notices 
SET target_role = 'student', target_user_id = target_student_id 
WHERE target_student_id IS NOT NULL AND target_user_id IS NULL;

-- 3. Atualizar RLS (Policies)
-- Como é complexo verificar roles em tabelas separadas no RLS, vamos manter uma política baseada na academia
-- e refinar a segurança: O usuário só vê avisos onde o target_user_id é ELE ou é NULL.
-- A filtragem por ROLE será reforçada no Application Level (App) ou com uma função auxiliar se necessário.

DROP POLICY IF EXISTS "Public view notices" ON public.notices;
DROP POLICY IF EXISTS "Todos podem ver avisos da sua academia" ON public.notices;

CREATE POLICY "Todos podem ver avisos da sua academia filtrados"
ON public.notices
FOR SELECT
USING (
  -- Pertence à mesma academia
  (id_academia IN (
      SELECT id_academia FROM users_alunos WHERE id = auth.uid()
      UNION
      SELECT id_academia FROM users_nutricionista WHERE id = auth.uid()
      UNION
      SELECT id_academia FROM users_personal WHERE id = auth.uid()
      UNION
      SELECT id FROM users_adm WHERE id = auth.uid() -- Admin é a própria academia
  ))
  AND
  -- E é direcionado a ele ou a todos
  (
    target_user_id IS NULL -- Para o grupo todo
    OR 
    target_user_id = auth.uid() -- Específico
  )
);

-- Admin pode fazer tudo (já coberto pelo id_academia se for o dono, mas garantindo)
CREATE POLICY "Admins full access notices"
ON public.notices FOR ALL
USING (
  id_academia = auth.uid() OR
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid() AND id = notices.id_academia)
);
