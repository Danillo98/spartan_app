-- CORREÇÃO DEFINITIVA DE EXCLUSÃO DE USUÁRIO E HISTÓRICO FINANCEIRO
-- 1. Assegura que constraints de deleção na tabela financeira sejam SET NULL
-- 2. Atualiza a função RPC de deleção para garantir o desligamento do vínculo financeiro antes da exclusão

-- PARTE 1: Garantir Schema do Banco (Foreign Key Segura)
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Remover qualquer FK em related_user_id (para recriar corretamente)
    FOR r IN 
        SELECT tc.constraint_name 
        FROM information_schema.table_constraints AS tc 
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY' 
          AND tc.table_name = 'financial_transactions' 
          AND kcu.column_name = 'related_user_id'
    LOOP
        EXECUTE 'ALTER TABLE public.financial_transactions DROP CONSTRAINT ' || quote_ident(r.constraint_name);
    END LOOP;
END $$;

-- Recriar FK com SET NULL
ALTER TABLE public.financial_transactions
ADD CONSTRAINT fk_financial_transactions_user_v2
FOREIGN KEY (related_user_id)
REFERENCES auth.users(id)
ON DELETE SET NULL;


-- PARTE 2: Atualizar Função RPC de Deleção (delete_user_complete)
-- Esta função é chamada pelo App para deletar usuários
CREATE OR REPLACE FUNCTION delete_user_complete(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role text;
  v_user_name text;
BEGIN
  -- Identificar Role e Nome (para preservar no histórico)
  IF EXISTS (SELECT 1 FROM users_alunos WHERE id = target_user_id) THEN
    v_role := 'Aluno';
    SELECT nome INTO v_user_name FROM users_alunos WHERE id = target_user_id;
  ELSIF EXISTS (SELECT 1 FROM users_nutricionista WHERE id = target_user_id) THEN
    v_role := 'Nutricionista';
    SELECT nome INTO v_user_name FROM users_nutricionista WHERE id = target_user_id;
  ELSIF EXISTS (SELECT 1 FROM users_personal WHERE id = target_user_id) THEN
    v_role := 'Personal';
    SELECT nome INTO v_user_name FROM users_personal WHERE id = target_user_id;
  ELSIF EXISTS (SELECT 1 FROM users_adm WHERE id = target_user_id) THEN
    v_role := 'Admin';
    SELECT nome INTO v_user_name FROM users_adm WHERE id = target_user_id;
  ELSE
    v_role := 'Usuário';
    v_user_name := 'Desconhecido';
  END IF;

  v_user_name := COALESCE(v_user_name, 'Sem Nome');

  -- 1. PROTEGER DADOS FINANCEIROS (CRÍTICO)
  -- Atualizar transações para remover o vínculo, mas preservando o NOME na descrição de forma inteligente
  UPDATE public.financial_transactions
  SET 
    related_user_id = NULL,
    description = CASE 
        WHEN position(v_user_name in description) > 0 THEN description || ' (' || v_role || ' Excluído)'
        ELSE description || ' - ' || v_user_name || ' (' || v_role || ' Excluído)'
    END
  WHERE related_user_id = target_user_id;

  -- 2. LIMPEZA DE DADOS RELACIONADOS (Agendamentos, Treinos, etc)
  
  -- Dietas
  UPDATE diets SET nutritionist_id = NULL WHERE nutritionist_id = target_user_id;
  DELETE FROM diets WHERE student_id = target_user_id;

  -- Treinos
  DELETE FROM workouts WHERE student_id = target_user_id;
  DELETE FROM physical_assessments WHERE student_id = target_user_id;

  -- Agendamentos
  DELETE FROM appointments WHERE student_id = target_user_id;
  -- Remover profissional de agendamentos (se array)
  -- UPDATE appointments SET professional_ids = array_remove(professional_ids, target_user_id::text) ...

  -- Notificações
  DELETE FROM notifications WHERE user_id = target_user_id;

  -- 3. DELETAR PERFIL (Tabelas públicas)
  DELETE FROM users_alunos WHERE id = target_user_id;
  DELETE FROM users_nutricionista WHERE id = target_user_id;
  DELETE FROM users_personal WHERE id = target_user_id;
  DELETE FROM users_adm WHERE id = target_user_id;

  -- 4. DELETAR CONTA DE AUTENTICAÇÃO (Auth.Users)
  DELETE FROM auth.users WHERE id = target_user_id;

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Erro fatal ao excluir usuário: %', SQLERRM;
END;
$$;
