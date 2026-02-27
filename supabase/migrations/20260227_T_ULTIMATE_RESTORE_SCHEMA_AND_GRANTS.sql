-- ============================================================
-- REPARO DE INFRAESTRUTURA: GRANTS E RELOAD SCHEMA
-- v2.5.8 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Este script replica a solução de estabilização usada ontem.
-- Ele restaura os privilégios de acesso e força o PostgREST
-- a recarregar o dicionário de dados do banco.
-- ============================================================

-- 1. RESTAURAR PRIVILÉGIOS (GRANTS)
-- ============================================================
-- Se o PostgREST não consegue ler o schema, geralmente é permissão de USAGE ou SELECT.
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;

-- Dar permissão de leitura em todas as tabelas públicas para os papéis de API
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- 2. GARANTIR EXTENSÕES NECESSÁRIAS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 3. FORÇAR RECARGA DO CACHE DA API (O "PULO DO GATO")
-- ============================================================
-- Isso limpa o erro "Database error querying schema" removendo o cache antigo.
NOTIFY pgrst, 'reload schema';


-- 4. VERIFICAÇÃO DE SAÚDE
-- ============================================================
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles 
FROM pg_policies 
WHERE tablename IN ('users_adm', 'users_nutricionista', 'users_personal', 'users_alunos');

SELECT '🚀 Schema recarregado e Grants restaurados! Tente o login agora.' as status;
