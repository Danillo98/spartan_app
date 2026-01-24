-- =============================================================================
-- AUTO-CONFIRMAÇÃO DE EMAIL PARA USUÁRIOS CRIADOS PELO ADMIN
-- =============================================================================

-- Esta trigger vai rodar IMEDIATAMENTE após a criação do usuário no Auth.
-- Ela vai definir o campo 'email_confirmed_at' para AGORA, liberando o login sem email.

CREATE OR REPLACE FUNCTION public.auto_confirm_users()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_role TEXT;
BEGIN
  -- Verificar o role nos metadados
  v_role := new.raw_user_meta_data->>'role';

  -- Se for criado pelo admin (nutri, personal, aluno) ou for o próprio admin
  -- Na verdade, você pediu para TODOS (Nutri, Personal, Aluno).
  -- O Admin (v_role = 'admin') geralmente se auto-cadastra e precisa verificar email?
  -- Seu pedido: "só o administrador vai receber email de verificação".
  
  IF v_role IN ('nutritionist', 'trainer', 'student') THEN
    -- Atualiza diretamente a tabela auth.users para confirmar o email
    -- Precisamos fazer um UPDATE porque o NEW é read-only em after trigger ou comportamento específico do Auth
    
    UPDATE auth.users
    SET email_confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = new.id;
  END IF;

  RETURN new;
END;
$$;

-- Criar trigger
DROP TRIGGER IF EXISTS trigger_auto_confirm ON auth.users;
CREATE TRIGGER trigger_auto_confirm
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_users();
