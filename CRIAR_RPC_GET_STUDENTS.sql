-- =============================================================================
-- BUSCAR ALUNOS DA MESMA ACADEMIA (PARA NUTRICIONISTAS E PERSONAIS)
-- =============================================================================
-- Como as tabelas estão protegidas por RLS, Nutricionistas não conseguem dar SELECT
-- na tabela de alunos diretamente (a menos que liberássemos tudo).
-- Esta função RPC permite listar APENAS os alunos da mesma academia do profissional.

CREATE OR REPLACE FUNCTION get_students_for_staff()
RETURNS TABLE (
  id UUID,
  nome TEXT,
  email TEXT,
  telefone TEXT,
  cnpj_academia TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  staff_cnpj TEXT;
  requesting_user_id UUID;
BEGIN
  requesting_user_id := auth.uid();
  
  -- 1. Descobre a qual academia o profissional pertence
  -- Tenta achar CNPJ na tabela de Nutricionistas
  SELECT u.cnpj_academia INTO staff_cnpj 
  FROM public.users_nutricionista u 
  WHERE u.id = requesting_user_id;
  
  -- Se não achou, tenta na tabela de Personal
  IF staff_cnpj IS NULL THEN
     SELECT u.cnpj_academia INTO staff_cnpj 
     FROM public.users_personal u 
     WHERE u.id = requesting_user_id;
  END IF;

  -- 2. Se encontrou uma academia, retorna os alunos dela
  IF staff_cnpj IS NOT NULL THEN
    RETURN QUERY
    SELECT a.id, a.nome, a.email, a.telefone, a.cnpj_academia
    FROM public.users_alunos a
    WHERE a.cnpj_academia = staff_cnpj;
  ELSE
    -- Se não achou (ex: é um Admin ou Aluno chamando, ou staff sem academia), retorna vazio.
    -- (Admins usam select direto, então não precisam dessa função)
    RETURN;
  END IF;
END;
$$;

SELECT 'Função get_students_for_staff criada com sucesso.' as status;
