-- =============================================================================
-- CRIAÇÃO DE FUNÇÃO SEGURA PARA VERIFICAÇÃO DE E-MAIL
-- =============================================================================
-- Esta função permite verificar se um e-mail existe no sistema mesmo sem estar logado.
-- Ela usa SECURITY DEFINER para ignorar as restrições RLS, mas retorna apenas true/false
-- para não vazar dados sensíveis.

CREATE OR REPLACE FUNCTION check_email_exists(email_input TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER -- Importante: Roda com permissão de admin para ler as tabelas protegidas
AS $$
BEGIN
  -- Verifica em todas as tabelas de forma case-insensitive
  IF EXISTS (SELECT 1 FROM public.users_adm WHERE email ILIKE email_input) THEN RETURN TRUE; END IF;
  IF EXISTS (SELECT 1 FROM public.users_nutricionista WHERE email ILIKE email_input) THEN RETURN TRUE; END IF;
  IF EXISTS (SELECT 1 FROM public.users_personal WHERE email ILIKE email_input) THEN RETURN TRUE; END IF;
  IF EXISTS (SELECT 1 FROM public.users_alunos WHERE email ILIKE email_input) THEN RETURN TRUE; END IF;
  
  RETURN FALSE;
END;
$$;

SELECT 'Função check_email_exists criada com sucesso.' as status;
