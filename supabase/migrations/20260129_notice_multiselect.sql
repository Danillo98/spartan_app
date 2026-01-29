-- SUPORTE A MÚLTIPLOS DESTINATÁRIOS EM AVISOS
-- Migra de target_user_id (singular) para target_user_ids (array JSONB).

-- 1. Adicionar coluna JSONB para lista de IDs
ALTER TABLE public.notices 
ADD COLUMN IF NOT EXISTS target_user_ids jsonb DEFAULT '[]'::jsonb;

-- 2. Migrar dados existentes
-- Quem tinha target_user_id preenchido, vira um array com 1 elemento.
UPDATE public.notices 
SET target_user_ids = jsonb_build_array(target_user_id)
WHERE target_user_id IS NOT NULL;

-- 3. Atualizar RLS (Policy)
-- O usuário vê o aviso se for publico (ids vazio/null) OU se o ID dele estiver no array.

DROP POLICY IF EXISTS "Todos podem ver avisos da sua academia filtrados" ON public.notices;

CREATE POLICY "Todos podem ver avisos da sua academia filtrados multi"
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
      SELECT id FROM users_adm WHERE id = auth.uid()
  ))
  AND
  -- Segmentação
  (
    -- Se a lista estiver vazia ou null, considera "Para Todos do Perfil" (que já é filtrado por target_role no App, mas aqui liberamos)
    (target_user_ids IS NULL OR jsonb_array_length(target_user_ids) = 0)
    OR 
    -- OU se o ID do usuário estiver contido no JSONB array
    target_user_ids @> to_jsonb(auth.uid())
  )
);
