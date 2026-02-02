-- ============================================
-- FUNÇÃO V3 (ROBUST): Deletar Academia por ID
-- ============================================
-- ATUALIZAÇÃO: Deleção Explícita em Cascata Manual
-- Motivo: Garantir que dados públicos sejam removidos mesmo se FKs falharem
-- ============================================

-- Remover versões anteriores
DROP FUNCTION IF EXISTS list_academia_users_v3(UUID);
DROP FUNCTION IF EXISTS delete_academia_by_id_v3(UUID);

-- 1. Função para LISTAR usuários da academia (Mantida igual)
CREATE OR REPLACE FUNCTION list_academia_users_v3(target_id_academia UUID)
RETURNS TABLE (
  output_user_id UUID,
  output_name TEXT,
  output_email TEXT,
  output_role TEXT,
  output_table_source TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT ua.id, ua.nome, ua.email, 'admin', 'users_adm' FROM public.users_adm ua WHERE ua.id = target_id_academia
  UNION ALL
  SELECT un.id, un.nome, un.email, 'nutritionist', 'users_nutricionista' FROM public.users_nutricionista un WHERE un.id_academia = target_id_academia
  UNION ALL
  SELECT up.id, up.nome, up.email, 'personal', 'users_personal' FROM public.users_personal up WHERE up.id_academia = target_id_academia
  UNION ALL
  SELECT ual.id, ual.nome, ual.email, 'student', 'users_alunos' FROM public.users_alunos ual WHERE ual.id_academia = target_id_academia;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Função PRINCIPAL para DELETAR (Versão Robusta)
CREATE OR REPLACE FUNCTION delete_academia_by_id_v3(target_id_academia UUID)
RETURNS JSON AS $$
DECLARE
  users_to_delete UUID[];
  deleted_count JSON;
  count_admins INTEGER := 0;
  count_nutris INTEGER := 0;
  count_personals INTEGER := 0;
  count_alunos INTEGER := 0;
  count_diets INTEGER := 0;
  count_workouts INTEGER := 0;
  count_notices INTEGER := 0;
  count_assessments INTEGER := 0;
  count_auth INTEGER := 0;
BEGIN
  -- Verificar se a academia (Admin) existe (ou existia, caso tenha sobrado lixo)
  -- Se não achar na users_adm, tenta ver se tem orfãos, mas o principal é achar o ID alvo.
  
  -- 1. Coletar IDs de TODOS os usuários para deletar do Auth depois
  SELECT ARRAY_AGG(output_user_id) INTO users_to_delete
  FROM list_academia_users_v3(target_id_academia);

  IF users_to_delete IS NULL THEN
     -- Se não achou ninguém, pode ser que o admin já tenha ido, mas sobraram orfãos?
     -- Vou permitir continuar se tiver lixo linkado ao id_academia, mas user principal avisa.
     -- Por segurança, se não tem admin, aborta ou avisa.
     -- Vamos assumir que se não tem usuários listados, não tem nada.
      RETURN json_build_object(
        'success', false,
        'message', 'Nenhum usuário encontrado para este ID de Academia',
        'id_academia', target_id_academia
      );
  END IF;

  -- 2. DELEÇÃO MANUAL DE CONTEÚDO (Tabelas Filhas)
  -- Deletamos tudo que tem id_academia = target
  
  -- Dietas
  WITH d AS (DELETE FROM public.diets WHERE id_academia = target_id_academia RETURNING id)
  SELECT COUNT(*) INTO count_diets FROM d;

  -- Treinos
  WITH w AS (DELETE FROM public.workouts WHERE id_academia = target_id_academia RETURNING id)
  SELECT COUNT(*) INTO count_workouts FROM w;
  
  -- Avisos
  WITH n AS (DELETE FROM public.notices WHERE id_academia = target_id_academia RETURNING id)
  SELECT COUNT(*) INTO count_notices FROM n;
  
  -- Avaliações Físicas
  WITH p AS (DELETE FROM public.physical_assessments WHERE id_academia = target_id_academia RETURNING id)
  SELECT COUNT(*) INTO count_assessments FROM p;

  -- (Adicione outras tabelas aqui se houver: appointments, financial, etc)
  DELETE FROM public.appointments WHERE id_academia = target_id_academia;

  -- 3. DELEÇÃO MANUAL DE USUÁRIOS PÚBLICOS
  
  -- Alunos
  WITH da AS (DELETE FROM public.users_alunos WHERE id_academia = target_id_academia RETURNING id)
  SELECT COUNT(*) INTO count_alunos FROM da;

  -- Personals
  WITH dp AS (DELETE FROM public.users_personal WHERE id_academia = target_id_academia RETURNING id)
  SELECT COUNT(*) INTO count_personals FROM dp;

  -- Nutricionistas
  WITH dn AS (DELETE FROM public.users_nutricionista WHERE id_academia = target_id_academia RETURNING id)
  SELECT COUNT(*) INTO count_nutris FROM dn;

  -- Admin (Dono)
  WITH dad AS (DELETE FROM public.users_adm WHERE id = target_id_academia RETURNING id)
  SELECT COUNT(*) INTO count_admins FROM dad;


  -- 4. DELEÇÃO DE AUTH.USERS (Final)
  -- Agora que limpamos as referências públicas, podemos apagar do Auth.
  -- Se sobrar algo na users_adm (ex: constraint falhou), o delete do auth deve cuidar ou falhar.
  -- Como já deletamos manualmente, isso é garantido.
  IF users_to_delete IS NOT NULL THEN
      WITH dau AS (
        DELETE FROM auth.users
        WHERE id = ANY(users_to_delete)
        RETURNING id
      )
      SELECT COUNT(*) INTO count_auth FROM dau;
  END IF;

  -- 5. Relatório
  SELECT json_build_object(
    'success', true,
    'message', 'Limpeza completa realizada com sucesso (Modo Explícito)',
    'id_academia', target_id_academia,
    'deleted_counts', json_build_object(
      'admins', count_admins,
      'nutritionists', count_nutris,
      'personals', count_personals,
      'students', count_alunos,
      'diets', count_diets,
      'workouts', count_workouts,
      'notices', count_notices,
      'assessments', count_assessments,
      'auth_users', count_auth
    )
  ) INTO deleted_count;

  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Permissões
GRANT EXECUTE ON FUNCTION list_academia_users_v3(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION list_academia_users_v3(UUID) TO postgres;
GRANT EXECUTE ON FUNCTION delete_academia_by_id_v3(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION delete_academia_by_id_v3(UUID) TO postgres;
