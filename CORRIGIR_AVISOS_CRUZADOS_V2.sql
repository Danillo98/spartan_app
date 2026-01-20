-- ========================================================
-- CORREÇÃO DEFINITIVA BUG DE AVISOS CRUZADOS
-- ========================================================

-- Problema identificado: A política "Read Access" atual permite que QUALQUER 
-- usuário da academia (Nutri, Personal, Aluno) veja avisos se eles forem "da mesma academia"
-- E se (target_student_id is null OR target_student_id = auth.uid()) for verdadeiro.
--
-- O ERRO: Um Personal NÃO É o aluno alvo do Nutricionista (target_student_id do aviso do Nutri é o ID do aluno, não do Personal).
-- Porém, a cláusula OR estava permitindo a "Others" ver avisos se o target fosse NULL **OU** se fosse ele mesmo.
--
-- Vamos tornar a política RÍGIDA e SEGREGADA por papel (Role).

-- 1. Remover políticas antigas
DROP POLICY IF EXISTS "Read Access" ON public.notices;
DROP POLICY IF EXISTS "Write Access" ON public.notices;

-- 2. Política de LEITURA (SELECT)

CREATE POLICY "notices_select_policy" ON public.notices
FOR SELECT
USING (
  -- CASO 1: O próprio autor vê seus avisos sempre (Nutri vê os que ele criou, Personal idem)
  created_by = auth.uid()
  
  OR
  
  -- CASO 2: Admin vê TUDO da sua academia
  EXISTS (
    SELECT 1 FROM public.users_adm 
    WHERE users_adm.id = auth.uid() 
    AND users_adm.cnpj_academia = notices.cnpj_academia
  )
  
  OR 
  
  -- CASO 3: Destinatário específico (target_student_id) vê o aviso, SE for da mesma academia
  (
    target_student_id = auth.uid()
    AND
    -- (Opcional, mas seguro) Verifica se o usuário logado pertence à mesma academia do aviso
    (
       EXISTS (SELECT 1 FROM public.users_alunos WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
       OR
       -- Nutri e Personal também podem receber avisos DIRECIONADOS A ELES (funcionalidade futura, mas já deixa pronto)
       EXISTS (SELECT 1 FROM public.users_nutricionista WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
       OR
       EXISTS (SELECT 1 FROM public.users_personal WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
    )
  )

  OR

  -- CASO 4: Avisos GERAIS (target_student_id IS NULL)
  -- Aqui está o pulo do gato: Quem pode ver avisos gerais? Todos da academia.
  (
    target_student_id IS NULL
    AND
    (
       EXISTS (SELECT 1 FROM public.users_alunos WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
       OR
       EXISTS (SELECT 1 FROM public.users_nutricionista WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
       OR
       EXISTS (SELECT 1 FROM public.users_personal WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
    )
  )
);

-- 3. Política de ESCRITA (INSERT/UPDATE/DELETE)
-- Mantida permissiva para criação por profissionais, mas restrita à academia

CREATE POLICY "notices_write_policy" ON public.notices
FOR ALL
USING (
  -- Admins da academia
  EXISTS (SELECT 1 FROM public.users_adm WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
  OR
  -- Nutricionistas da academia
  EXISTS (SELECT 1 FROM public.users_nutricionista WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
  OR
  -- Personais da academia
  EXISTS (SELECT 1 FROM public.users_personal WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
)
WITH CHECK (
  -- Mesma checagem para garantir que não criem para outra academia
  EXISTS (SELECT 1 FROM public.users_adm WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
  OR
  EXISTS (SELECT 1 FROM public.users_nutricionista WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
  OR
  EXISTS (SELECT 1 FROM public.users_personal WHERE id = auth.uid() AND cnpj_academia = notices.cnpj_academia)
);

-- ========================================================
-- FIM DA CORREÇÃO
-- Execute este script no SQL Editor
