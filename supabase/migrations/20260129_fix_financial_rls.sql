-- CORREÇÃO DE PERMISSÕES (RLS) NA TABELA FINANCEIRA
-- Habilita Row Level Security e permite que Admins e Alunos vejam seus dados.
-- Isso é NECESSÁRIO para que o App consiga verificar se o aluno pagou a mensalidade ao fazer login.

-- 1. Habilitar RLS
ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;

-- 2. Política para ADMIN (Ver tudo da sua academia)
DROP POLICY IF EXISTS "Admins podem ver transações da sua academia" ON public.financial_transactions;

CREATE POLICY "Admins podem ver transações da sua academia"
ON public.financial_transactions
FOR ALL
USING (
  -- Verifica se o usuário é Admin e se o id_academia bate
  -- Como id_academia na transação é o ID do Admin (Owner), basta comparar
  id_academia = auth.uid() 
  OR 
  -- Ou se o usuário é um admin registrado na tabela users_adm (caso haja hierarquia)
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid() AND id = financial_transactions.id_academia)
);

-- 3. Política para USUÁRIOS/ALUNOS (Ver apenas suas transações)
DROP POLICY IF EXISTS "Usuários podem ver suas próprias transações" ON public.financial_transactions;

CREATE POLICY "Usuários podem ver suas próprias transações"
ON public.financial_transactions
FOR SELECT
USING (
  related_user_id = auth.uid()
);

-- Garantir acesso ao Schema public
GRANT SELECT ON public.financial_transactions TO authenticated;
