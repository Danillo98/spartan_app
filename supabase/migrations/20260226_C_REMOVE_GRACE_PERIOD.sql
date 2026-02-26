-- 1. Remover a coluna de carência da tabela de alunos
ALTER TABLE public.users_alunos DROP COLUMN IF EXISTS grace_period;

-- 2. Atualizar todos os alunos atuais: soma 3 dias ao vencimento (limite de 31)
UPDATE public.users_alunos 
SET payment_due_day = CASE 
    WHEN payment_due_day + 3 > 31 THEN 31 
    ELSE payment_due_day + 3 
END
WHERE payment_due_day IS NOT NULL;

-- 3. Notificar o Supabase para recarregar o esquema e evitar o erro que vimos antes
NOTIFY pgrst, 'reload schema';
