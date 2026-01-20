-- ============================================
-- FUNÇÃO: Deletar Academia Completa
-- ============================================
-- Esta função deleta TODOS os dados de uma academia específica
-- incluindo: Admins, Nutricionistas, Personals e Alunos
-- 
-- ATENÇÃO: Esta ação é IRREVERSÍVEL!
-- ============================================

CREATE OR REPLACE FUNCTION delete_academia_cnpj(academia_cnpj TEXT)
RETURNS JSON AS $$
DECLARE
  admin_ids UUID[];
  deleted_count JSON;
BEGIN
  -- 1. Buscar todos os IDs de administradores da academia
  SELECT ARRAY_AGG(id) INTO admin_ids
  FROM public.users
  WHERE role = 'admin' AND cnpj = _cnpj;

  -- Verificar se encontrou algum admin
  IF admin_ids IS NULL OR array_length(admin_ids, 1) IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Nenhuma academia encontrada com este CNPJ',
      'cnpj', academia_cnpj
    );
  END IF;

  -- 2. Deletar todos os usuários relacionados à academia
  -- (Nutricionistas, Personals e Alunos que têm admin_id)
  WITH deleted_users AS (
    DELETE FROM public.users
    WHERE admin_id = ANY(admin_ids)
    RETURNING id, role
  ),
  -- 3. Deletar os administradores
  deleted_admins AS (
    DELETE FROM public.users
    WHERE id = ANY(admin_ids)
    RETURNING id
  ),
  -- 4. Deletar da tabela auth.users
  deleted_auth AS (
    DELETE FROM auth.users
    WHERE id IN (
      SELECT id FROM deleted_users
      UNION
      SELECT id FROM deleted_admins
    )
    RETURNING id
  )
  -- 5. Contar quantos foram deletados
  SELECT json_build_object(
    'success', true,
    'message', 'Academia deletada com sucesso',
    'cnpj', academia_cnpj,
    'deleted', json_build_object(
      'users', (SELECT COUNT(*) FROM deleted_users),
      'admins', (SELECT COUNT(*) FROM deleted_admins),
      'auth_users', (SELECT COUNT(*) FROM deleted_auth)
    )
  ) INTO deleted_count;

  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- COMO USAR:
-- ============================================

-- Exemplo 1: Deletar academia pelo CNPJ
-- SELECT delete_academia_cnpj('53870683000102');

-- Exemplo 2: Ver resultado detalhado
-- SELECT * FROM delete_academia_cnpj('53870683000102');

-- ============================================
-- RESULTADO ESPERADO:
-- ============================================
-- {
--   "success": true,
--   "message": "Academia deletada com sucesso",
--   "cnpj": "53870683000102",
--   "deleted": {
--     "users": 15,      -- Nutricionistas, Personals, Alunos
--     "admins": 1,      -- Administradores
--     "auth_users": 16  -- Total deletado do auth
--   }
-- }

-- ============================================
-- FUNÇÃO ALTERNATIVA: Deletar por Admin ID
-- ============================================

CREATE OR REPLACE FUNCTION delete_academia_admin_id(admin_user_id UUID)
RETURNS JSON AS $$
DECLARE
  academia_cnpj TEXT;
  deleted_count JSON;
BEGIN
  -- 1. Buscar CNPJ do admin
  SELECT cnpj INTO academia_cnpj
  FROM public.users
  WHERE id = admin_user_id AND role = 'admin';

  -- Verificar se encontrou
  IF academia_cnpj IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Administrador não encontrado',
      'admin_id', admin_user_id
    );
  END IF;

  -- 2. Usar a função principal
  SELECT delete_academia_cnpj(academia_cnpj) INTO deleted_count;

  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNÇÃO DE SEGURANÇA: Listar antes de deletar
-- ============================================

CREATE OR REPLACE FUNCTION list_academia_users(academia_cnpj TEXT)
RETURNS TABLE (
  id UUID,
  name TEXT,
  email TEXT,
  role TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  -- Buscar IDs dos admins
  RETURN QUERY
  WITH admin_ids AS (
    SELECT id FROM public.users
    WHERE role = 'admin' AND cnpj = academia_cnpj
  )
  -- Listar todos os usuários da academia
  SELECT 
    u.id,
    u.name,
    u.email,
    u.role,
    u.created_at
  FROM public.users u
  WHERE u.id IN (SELECT id FROM admin_ids)
     OR u.admin_id IN (SELECT id FROM admin_ids)
  ORDER BY 
    CASE u.role
      WHEN 'admin' THEN 1
      WHEN 'nutritionist' THEN 2
      WHEN 'personal' THEN 3
      WHEN 'student' THEN 4
    END,
    u.created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- EXEMPLO DE USO COMPLETO:
-- ============================================

-- 1. LISTAR usuários antes de deletar (RECOMENDADO!)
-- SELECT * FROM list_academia_users('53870683000102');

-- 2. DELETAR academia
-- SELECT delete_academia_cnpj('53870683000102');

-- 3. VERIFICAR se foi deletado
-- SELECT * FROM list_academia_users('53870683000102');
-- (Deve retornar 0 linhas)

-- ============================================
-- PERMISSÕES:
-- ============================================

-- Dar permissão para service_role executar
GRANT EXECUTE ON FUNCTION delete_academia_cnpj(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION delete_academia_admin_id(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION list_academia_users(TEXT) TO service_role;

-- ============================================
-- NOTAS IMPORTANTES:
-- ============================================

-- 1. Esta função é IRREVERSÍVEL
-- 2. SEMPRE liste os usuários antes de deletar
-- 3. Faça backup antes de usar em produção
-- 4. Use com MUITO cuidado!
-- 5. Considere adicionar soft delete ao invés de hard delete
