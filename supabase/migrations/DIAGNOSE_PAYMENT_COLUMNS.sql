-- ============================================
-- DIAGNÓSTICO COMPLETO: Estrutura de users_alunos
-- ============================================

-- 1. Listar TODAS as colunas relacionadas a payment
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'users_alunos'
AND column_name LIKE '%payment%'
ORDER BY ordinal_position;

-- 2. Verificar se payment_due_day existe
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'users_alunos' 
            AND column_name = 'payment_due_day'
        ) THEN '✅ payment_due_day EXISTE'
        ELSE '❌ payment_due_day NÃO EXISTE'
    END as status_payment_due_day;

-- 3. Verificar se payment_due existe
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'users_alunos' 
            AND column_name = 'payment_due'
        ) THEN '✅ payment_due EXISTE'
        ELSE '❌ payment_due NÃO EXISTE'
    END as status_payment_due;
