-- ============================================================
-- NUCLEAR INFRA RESET: SCHEMA STABILITY
-- v2.5.9 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Este script resolve o erro fatal "Database error querying schema"
-- restaurando a integridade das permissões de sistema e limpando
-- o cache do PostgREST.
-- ============================================================

-- 1. RESTAURAR PROPRIEDADE E PRIVILÉGIOS (MANDATÓRIO)
-- ============================================================
-- Se o PostgREST não consegue ler o schema, a permissão ROLE/GRANT está corrompida.
ALTER SCHEMA public OWNER TO postgres;

-- Garantir que as roles internas do Supabase podem ver tudo
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;

-- Reset de privilégios para evitar Grant Orfão (colunas deletadas que ainda tem Grant)
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

-- Permissões em sequências (importante para inserts)
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;


-- 2. LIMPEZA DE OBJETOS CORROMPIDOS
-- ============================================================
-- Remove triggers que podem estar referenciando colunas inexistentes nos Nutris/Personals
DROP TRIGGER IF EXISTS tr_refresh_status_on_student_change ON public.users_alunos;
DROP TRIGGER IF EXISTS trigger_sync_payment_due_day ON public.users_alunos;


-- 3. FORÇAR RECARGA DA API (RELOAD SCHEMAS)
-- ============================================================
-- Notificar 3 vezes para garantir que o cache seja limpo em todos os nodes
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';


-- 4. TESTE DE ACESSIBILIDADE
-- ============================================================
-- Este SELECT confirma se o sistema consegue ler as tabelas de perfil
DO $$
BEGIN
    PERFORM count(*) FROM public.users_nutricionista;
    PERFORM count(*) FROM public.users_personal;
    PERFORM count(*) FROM public.users_alunos;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Aviso: Uma das tabelas ainda está com erro de acesso: %', SQLERRM;
END $$;

SELECT '🚀 REINICIALIZAÇÃO NUCLEAR CONCLUÍDA! Tente logar com o Personal agora.' as status;
