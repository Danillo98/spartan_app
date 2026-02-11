-- ============================================
-- DEBUG: Verificar colunas exatas de users_alunos
-- ============================================

-- 1. Listar TODAS as colunas da tabela users_alunos
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'users_alunos'
ORDER BY ordinal_position;

-- 2. FORÇAR reload do schema (múltiplas vezes)
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload config';

-- 3. Aguardar 2 segundos
SELECT pg_sleep(2);

-- 4. Recarregar novamente
NOTIFY pgrst, 'reload schema';

SELECT '✅ Colunas listadas acima. Verifique se payment_due existe.' as status;
