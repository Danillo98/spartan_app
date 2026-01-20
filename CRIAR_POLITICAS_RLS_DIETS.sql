-- =============================================================================
-- POLÍTICAS RLS PARA TABELA DIETS
-- =============================================================================

-- Habilitar RLS na tabela diets (se ainda não estiver habilitado)
ALTER TABLE public.diets ENABLE ROW LEVEL SECURITY;

-- Política para NUTRICIONISTAS criarem dietas
CREATE POLICY "Nutricionistas podem criar dietas"
ON public.diets
FOR INSERT
TO authenticated
WITH CHECK (
  -- Verifica se o usuário é um nutricionista
  EXISTS (
    SELECT 1 FROM public.users_nutricionista
    WHERE id = auth.uid()
    AND id = nutritionist_id
  )
);

-- Política para NUTRICIONISTAS visualizarem suas próprias dietas
CREATE POLICY "Nutricionistas podem ver suas dietas"
ON public.diets
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users_nutricionista
    WHERE id = auth.uid()
    AND id = nutritionist_id
  )
);

-- Política para NUTRICIONISTAS atualizarem suas próprias dietas
CREATE POLICY "Nutricionistas podem atualizar suas dietas"
ON public.diets
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users_nutricionista
    WHERE id = auth.uid()
    AND id = nutritionist_id
  )
);

-- Política para NUTRICIONISTAS deletarem suas próprias dietas
CREATE POLICY "Nutricionistas podem deletar suas dietas"
ON public.diets
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users_nutricionista
    WHERE id = auth.uid()
    AND id = nutritionist_id
  )
);

-- Política para ALUNOS visualizarem suas próprias dietas
CREATE POLICY "Alunos podem ver suas dietas"
ON public.diets
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users_alunos
    WHERE id = auth.uid()
    AND id = student_id
  )
);

-- Política para ADMINS terem acesso total às dietas da sua academia
CREATE POLICY "Admins podem gerenciar dietas da academia"
ON public.diets
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users_adm
    WHERE id = auth.uid()
    AND cnpj_academia = diets.cnpj_academia
  )
);

SELECT 'Políticas RLS para diets criadas com sucesso!' as status;
