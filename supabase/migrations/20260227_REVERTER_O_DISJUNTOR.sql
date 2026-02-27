-- ============================================================
-- ARQUIVO FINAL: DESFAZER O DISJUNTOR GERAL
-- ============================================================
-- Você pediu para não estragar nada. Esse é o script que rola
-- de volta exatamente a estrutura de antes do meu DISJUNTOR.
-- Se o Disjuntor Geral não resolveu, significa que a falha não é 
-- RLS cruzada. O Supabase só dá esse erro "Database error querying schema" 
-- no login de UM usuário específico e não de outros por DOIS motivos:
--
-- 1. As Claims do JWT foram mal formatadas (json corrompido).
-- 2. Há um trigger de banco de dados rodando on INSERT no auth.users
-- que está quebrando silenciosamente porque o JWT ou ID é novo, 
-- e o trigger trava a request da API.
-- ============================================================

-- REATIVA RLS
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', r.tablename);
    END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';

SELECT '✅ Sistema revertido com sucesso. RLS LIGADO NOVAMENTE.' as status;
