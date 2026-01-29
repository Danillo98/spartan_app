-- PROTEÇÃO DE DADOS FINANCEIROS
-- Impede que a exclusão de um usuário apague automaticamente suas transações financeiras.
-- Substitui qualquer constraint existente por ON DELETE SET NULL.

DO $$
DECLARE
    r RECORD;
BEGIN
    -- 1. Buscar e remover qualquer Constraint de Foreign Key ligada à coluna related_user_id
    FOR r IN 
        SELECT tc.constraint_name 
        FROM information_schema.table_constraints AS tc 
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY' 
          AND tc.table_name = 'financial_transactions' 
          AND kcu.column_name = 'related_user_id'
    LOOP
        RAISE NOTICE 'Removendo constraint antiga: %', r.constraint_name;
        EXECUTE 'ALTER TABLE public.financial_transactions DROP CONSTRAINT ' || quote_ident(r.constraint_name);
    END LOOP;
END $$;

-- 2. Recriar a Foreign Key com a regra de proteção (ON DELETE SET NULL)
-- Isso garante que se o usuário (auth.users) for deletado, o ID na transação vira NULL, mas o registro fica.
ALTER TABLE public.financial_transactions
ADD CONSTRAINT fk_financial_transactions_user
FOREIGN KEY (related_user_id)
REFERENCES auth.users(id)
ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_financial_transactions_user ON public.financial_transactions IS 
'Garante que transações financeiras sejam preservadas (com user_id nulo) mesmo se o usuário for excluído.';
