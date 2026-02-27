-- ============================================================
-- EMERGENCY FIX: BYPASS RLS FOR LOGIN DIAGNOSIS
-- v2.5.7 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Este script DESATIVA temporariamente a RLS para testar se
-- o problema de login é realmente RLS ou se há algo mais
-- profundo (como falha no PostgREST ou schema corrompido).
-- ============================================================

-- 1. DESATIVAR RLS TEMPORARIAMENTE
-- ------------------------------------------------------------
ALTER TABLE public.users_adm DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_nutricionista DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_personal DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_alunos DISABLE ROW LEVEL SECURITY;

-- 2. RESETAR CACHE POSTGREST
-- ------------------------------------------------------------
NOTIFY pgrst, 'reload schema';

SELECT '⚠️ RLS DESATIVADA TEMPORARIAMENTE para as tabelas de usuários.' as status,
       'Tente logar agora. Se o erro persistir, o problema NÃO é RLS.' as instrucao;
