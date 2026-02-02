-- ============================================
-- FUNÇÃO CORRIGIDA: Deletar Academia Completa V2
-- ============================================
-- Esta função deleta TODOS os dados de uma academia específica
-- Corrigindo nomes de colunas (admin_id -> created_by_admin_id)
-- e parâmetros (_cnpj -> academia_cnpj)
-- ============================================

-- 1. Função para LISTAR usuários (Segurança)
CREATE OR REPLACE FUNCTION list_academia_users_v2(target_cnpj TEXT)
RETURNS TABLE (
  id UUID,
  name TEXT,
  email TEXT,
  role TEXT,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  found_admin_ids UUID[];
BEGIN
  -- Buscar IDs dos admins
  SELECT ARRAY_AGG(id) INTO found_admin_ids
  FROM public.users
  WHERE role = 'admin' AND cnpj = target_cnpj;

  -- Retornar tabela
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    u.email,
    u.role,
    u.created_at
  FROM public.users u
  WHERE u.id = ANY(found_admin_ids) 
     OR u.created_by_admin_id = ANY(found_admin_ids)
  ORDER BY u.role, u.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Função PRINCIPAL para DELETAR por CNPJ
CREATE OR REPLACE FUNCTION delete_academia_cnpj_v2(target_cnpj TEXT)
RETURNS JSON AS $$
DECLARE
  admin_ids UUID[];
  deleted_count JSON;
BEGIN
  -- 1. Buscar todos os IDs de administradores da academia
  SELECT ARRAY_AGG(id) INTO admin_ids
  FROM public.users
  WHERE role = 'admin' AND cnpj = target_cnpj;

  -- Verificar se encontrou algum admin
  IF admin_ids IS NULL OR array_length(admin_ids, 1) IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Nenhuma academia encontrada com este CNPJ',
      'cnpj', target_cnpj
    );
  END IF;

  -- 2. Deletar todos os usuários relacionados à academia
  -- (Nutricionistas, Personals e Alunos criados pelo admin)
  WITH deleted_users AS (
    DELETE FROM public.users
    WHERE created_by_admin_id = ANY(admin_ids)
    AND id != ALL(admin_ids) -- Garantir que não deleta o admin ainda
    RETURNING id
  ),
  -- 3. Deletar os administradores
  deleted_admins AS (
    DELETE FROM public.users
    WHERE id = ANY(admin_ids)
    RETURNING id
  ),
  -- 4. Deletar da tabela auth.users (Cascata manual por segurança)
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
    'cnpj', target_cnpj,
    'deleted', json_build_object(
      'users', (SELECT COUNT(*) FROM deleted_users),
      'admins', (SELECT COUNT(*) FROM deleted_admins),
      'auth_users', (SELECT COUNT(*) FROM deleted_auth)
    )
  ) INTO deleted_count;

  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Função Auxiliar: Deletar por ID do Admin (caso não tenha CNPJ fácil)
CREATE OR REPLACE FUNCTION delete_academia_admin_id_v2(target_admin_id UUID)
RETURNS JSON AS $$
DECLARE
  found_cnpj TEXT;
  deleted_count JSON;
BEGIN
  -- 1. Buscar CNPJ do admin
  SELECT cnpj INTO found_cnpj
  FROM public.users
  WHERE id = target_admin_id AND role = 'admin';

  -- Verificar se encontrou
  IF found_cnpj IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Administrador não encontrado ou não possui CNPJ',
      'admin_id', target_admin_id
    );
  END IF;

  -- 2. Usar a função principal
  SELECT delete_academia_cnpj_v2(found_cnpj) INTO deleted_count;

  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Permissões
GRANT EXECUTE ON FUNCTION list_academia_users_v2(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION list_academia_users_v2(TEXT) TO postgres;
GRANT EXECUTE ON FUNCTION delete_academia_cnpj_v2(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION delete_academia_cnpj_v2(TEXT) TO postgres;
GRANT EXECUTE ON FUNCTION delete_academia_admin_id_v2(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION delete_academia_admin_id_v2(UUID) TO postgres;
