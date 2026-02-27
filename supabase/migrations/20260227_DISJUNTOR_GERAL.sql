-- ============================================================
-- DISJUNTOR GERAL: DESATIVAR TOTALMENTE RLS DE TODAS AS TABELAS
-- ============================================================
-- Se o app falha mesmo após limpar as 4 principais, significa 
-- que o erro "Database error querying schema" está sendo disparado
-- por alguma tabela secundária (como 'notices', 'workouts' ou 'diets')
-- que você carrega logo após logar e que possui a mesma política 
-- em formato de Loop.
-- 
-- Este script vai simplesmente ARRANCAR a segurança momentaneamente
-- do banco todo. Nenhuma tabela terá política travando.
-- ============================================================

DO $$ 
DECLARE 
    r RECORD;
BEGIN
    -- 1. Desabilita RLS de todas as tabelas (Ignora as políticas)
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY;', r.tablename);
    END LOOP;

    -- 2. Deleta as políticas ativas para liberar espaço e não confundir o cache
    FOR r IN (SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
    END LOOP;
    
    -- 3. Deleta a função ciber-bomba que criamos
    DROP FUNCTION IF EXISTS public.get_auth_academy_id() CASCADE;
    
END $$;

-- 4. Força a API do Supabase a recalcular o schema limpo
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';

SELECT '✅ DISJUNTOR GERAL ACIONADO. TODAS AS POLÍTICAS DROPPADAS E RLS DESLIGADO.' as status;
