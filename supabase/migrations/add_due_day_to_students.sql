-- Adiciona coluna para dia de vencimento da mensalidade na tabela de alunos
ALTER TABLE users_alunos 
ADD COLUMN payment_due_day INTEGER CHECK (payment_due_day >= 1 AND payment_due_day <= 31);
