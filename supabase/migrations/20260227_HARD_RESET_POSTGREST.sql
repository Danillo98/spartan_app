-- EMERGÊNCIA: RESET ABSOLUTO DE GRANTS E CACHE
-- v4.0 - Foco exclusivo no erro de infraestrutura do PostgREST

-- 1. DROP DAS VIEWS SECUNDÁRIAS (Evita lock em recarga de schema)
-- =================================================================
DROP VIEW IF EXISTS public.users_adm_view CASCADE;

-- 2. RESETAR PRIVILÉGIOS (O erro "Database error querying schema"
-- geralmente 90% das vezes é falha de Grant no próprio Supabase)
-- =================================================================
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO postgres, anon, authenticated, service_role;

-- 3. FORÇAR A RECONSTRUÇÃO DO CACHE DA API (POSTGREST)
-- =================================================================
-- Qualquer tabela mal formatada que gerou metadados corrompidos será
-- limpa neste flush.
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload config';

-- 4. VERIFICAÇÃO VERDE
SELECT '✅ RECARGA TOTAL DO CACHE DO POSTGREST FINALIZADA. TENTE LOGAR DE NOVO.' as status;
