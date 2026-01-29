-- MELHORIA NA TABELA DE AVALIAÇÕES FÍSICAS
-- Permite que avaliações sejam criadas por Admins e tenham Personal ou Nutricionista opcionais.

-- 1. Adicionar coluna personal_id
ALTER TABLE public.physical_assessments 
ADD COLUMN IF NOT EXISTS personal_id uuid REFERENCES public.users_personal(id);

-- 2. Tornar nutritionist_id opcional (pode ser só personal, ou só admin criando sem definir ainda)
ALTER TABLE public.physical_assessments 
ALTER COLUMN nutritionist_id DROP NOT NULL;

-- 3. Adicionar índices para performance nas buscas por profissional
CREATE INDEX IF NOT EXISTS idx_physical_assessments_personal_id ON public.physical_assessments(personal_id);

-- 4. Atualizar Policies (Permissões)
-- Admin pode fazer tudo (já deve ter policy global, mas garantindo)
-- Personal pode ver/criar suas avaliações
CREATE POLICY "Personal can view assessments assigned to them"
ON public.physical_assessments FOR SELECT
USING (auth.uid() = personal_id);

CREATE POLICY "Personal can update assessments assigned to them"
ON public.physical_assessments FOR UPDATE
USING (auth.uid() = personal_id);

-- Ajustar policy do Nutricionista para lidar com null (se necessário, mas a existente deve funcionar se ele for o dono)
