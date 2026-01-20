-- ============================================
-- 🔍 DIAGNÓSTICO COMPLETO DO SUPABASE
-- ============================================
-- Execute este script no SQL Editor do Supabase
-- para verificar o estado atual do sistema

-- ============================================
-- 1. VERIFICAR USUÁRIOS CRIADOS
-- ============================================

SELECT 
  '📊 USUÁRIOS NO AUTH.USERS' as info,
  COUNT(*) as total
FROM auth.users;

SELECT 
  id,
  email,
  email_confirmed_at,
  created_at,
  CASE 
    WHEN email_confirmed_at IS NULL THEN '❌ Não confirmado'
    ELSE '✅ Confirmado'
  END as status
FROM auth.users
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- 2. VERIFICAR USUÁRIOS NA TABELA PUBLIC.USERS
-- ============================================

SELECT 
  '📊 USUÁRIOS NO PUBLIC.USERS' as info,
  COUNT(*) as total
FROM public.users;

SELECT 
  id,
  name,
  email,
  role,
  email_verified,
  created_at
FROM public.users
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- 3. VERIFICAR DISCREPÂNCIAS
-- ============================================

-- Usuários no auth.users mas não no public.users
SELECT 
  '⚠️ NO AUTH MAS NÃO NO PUBLIC' as problema,
  au.email,
  au.created_at
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL;

-- Usuários no public.users mas não no auth.users
SELECT 
  '⚠️ NO PUBLIC MAS NÃO NO AUTH' as problema,
  pu.email,
  pu.created_at
FROM public.users pu
LEFT JOIN auth.users au ON pu.id = au.id
WHERE au.id IS NULL;

-- ============================================
-- 4. VERIFICAR EMAILS DUPLICADOS
-- ============================================

SELECT 
  email,
  COUNT(*) as quantidade,
  CASE 
    WHEN COUNT(*) > 1 THEN '⚠️ DUPLICADO!'
    ELSE '✅ OK'
  END as status
FROM auth.users
GROUP BY email
HAVING COUNT(*) > 1;

-- ============================================
-- 5. LIMPAR USUÁRIOS DE TESTE (OPCIONAL)
-- ============================================

-- ⚠️ CUIDADO! Isso vai deletar usuários de teste
-- Descomente apenas se quiser limpar:

-- DELETE FROM auth.users WHERE email LIKE '%teste%';
-- DELETE FROM public.users WHERE email LIKE '%teste%';

-- ============================================
-- 6. VERIFICAR CONFIGURAÇÃO DE EMAIL
-- ============================================

-- Verificar se há configuração de SMTP customizada
SELECT 
  '📧 CONFIGURAÇÃO DE EMAIL' as info,
  *
FROM auth.config
WHERE name LIKE '%smtp%' OR name LIKE '%email%';

-- ============================================
-- 7. VERIFICAR LOGS DE AUTENTICAÇÃO (últimas 24h)
-- ============================================

-- Nota: Esta tabela pode não existir em todos os projetos
-- Se der erro, comente esta seção

-- SELECT 
--   created_at,
--   event_type,
--   user_id,
--   email,
--   error_message
-- FROM auth.audit_log_entries
-- WHERE created_at > NOW() - INTERVAL '24 hours'
-- ORDER BY created_at DESC
-- LIMIT 50;

-- ============================================
-- 8. RESUMO FINAL
-- ============================================

SELECT 
  '📊 RESUMO' as categoria,
  'Total de usuários no auth.users' as metrica,
  COUNT(*) as valor
FROM auth.users
UNION ALL
SELECT 
  '📊 RESUMO',
  'Total de usuários no public.users',
  COUNT(*)
FROM public.users
UNION ALL
SELECT 
  '📊 RESUMO',
  'Usuários não confirmados',
  COUNT(*)
FROM auth.users
WHERE email_confirmed_at IS NULL
UNION ALL
SELECT 
  '📊 RESUMO',
  'Usuários confirmados',
  COUNT(*)
FROM auth.users
WHERE email_confirmed_at IS NOT NULL;

-- ============================================
-- 9. COMANDOS ÚTEIS
-- ============================================

-- Para deletar um usuário específico:
-- DELETE FROM auth.users WHERE email = 'email@exemplo.com';
-- DELETE FROM public.users WHERE email = 'email@exemplo.com';

-- Para confirmar email manualmente (APENAS PARA TESTE):
-- UPDATE auth.users 
-- SET email_confirmed_at = NOW() 
-- WHERE email = 'email@exemplo.com';

-- Para ver detalhes de um usuário específico:
-- SELECT * FROM auth.users WHERE email = 'email@exemplo.com';
-- SELECT * FROM public.users WHERE email = 'email@exemplo.com';
