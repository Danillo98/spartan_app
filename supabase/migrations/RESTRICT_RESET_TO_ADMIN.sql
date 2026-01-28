-- FUNÇÃO PARA VERIFICAR SE O EMAIL É DE UM ADMINISTRADOR
-- Usado para restringir a recuperação de senha apenas para Admins

CREATE OR REPLACE FUNCTION check_admin_email_exists(email_input TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verifica APENAS na tabela users_adm
  IF EXISTS (SELECT 1 FROM public.users_adm WHERE email ILIKE email_input) THEN 
    RETURN TRUE; 
  END IF;
  
  RETURN FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION check_admin_email_exists(TEXT) TO anon, authenticated, service_role;
