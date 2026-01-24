-- CORRECAO_DEFINITIVA_TRIGGER.sql
-- =============================================================================
-- TRIGGER AUTO-CLEAN (FIM DA NECESSIDADE DE SCRIPTS MANUAIS)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_name TEXT;
  v_academia TEXT;
  v_cnpj_academia TEXT;
  v_phone TEXT;
  v_created_by_admin_id UUID;
  v_payment_due_day INTEGER;
BEGIN
  -- 1. Recuperar metadados
  v_role := new.raw_user_meta_data->>'role';
  v_name := new.raw_user_meta_data->>'name';
  v_academia := new.raw_user_meta_data->>'academia';
  v_cnpj_academia := new.raw_user_meta_data->>'cnpj_academia';
  v_phone := new.raw_user_meta_data->>'phone';
  
  -- Tratamento de ID do Admin
  BEGIN
    v_created_by_admin_id := (new.raw_user_meta_data->>'created_by_admin_id')::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_created_by_admin_id := NULL;
  END;

  -- Se não tiver role, não faz nada (pode ser cadastro de sistema)
  IF v_role IS NULL THEN
    RETURN new;
  END IF;

  -- ========================================================================
  -- 2. AUTO-LIMPEZA DE ORFÃOS (A MÁGICA)
  -- Se o email já existe em alguma tabela pública mas não bloqueou o Auth,
  -- é porque é um registro órfão. Vamos deletar antes de inserir.
  -- ========================================================================
  
  DELETE FROM public.users_nutricionista WHERE email = new.email;
  DELETE FROM public.users_personal WHERE email = new.email;
  DELETE FROM public.users_alunos WHERE email = new.email;
  -- Não deletamos admin automaticamente por segurança, mas nos outros perfis é seguro.

  -- ========================================================================
  -- 3. INSERÇÃO LIMPA
  -- ========================================================================

  IF v_role = 'admin' THEN
    INSERT INTO public.users_adm (id, email, nome, academia, cnpj_academia, telefone)
    VALUES (new.id, new.email, v_name, v_academia, v_cnpj_academia, v_phone)
    ON CONFLICT (id) DO UPDATE SET
      nome = EXCLUDED.nome,
      academia = EXCLUDED.academia,
      cnpj_academia = EXCLUDED.cnpj_academia;
      
  ELSIF v_role = 'nutritionist' THEN
    INSERT INTO public.users_nutricionista (id, email, nome, academia, cnpj_academia, telefone, created_by_admin_id)
    VALUES (new.id, new.email, v_name, v_academia, v_cnpj_academia, v_phone, v_created_by_admin_id);
    
  ELSIF v_role = 'trainer' THEN
    INSERT INTO public.users_personal (id, email, nome, academia, cnpj_academia, telefone, created_by_admin_id)
    VALUES (new.id, new.email, v_name, v_academia, v_cnpj_academia, v_phone, v_created_by_admin_id);
    
  ELSIF v_role = 'student' THEN
    v_payment_due_day := (new.raw_user_meta_data->>'paymentDueDay')::INTEGER;
    INSERT INTO public.users_alunos (id, email, nome, academia, cnpj_academia, telefone, created_by_admin_id, payment_due_day)
    VALUES (new.id, new.email, v_name, v_academia, v_cnpj_academia, v_phone, v_created_by_admin_id, v_payment_due_day);
  END IF;

  -- ========================================================================
  -- 4. CONFIRMAÇÃO AUTOMÁTICA DE EMAIL
  -- Garante que o usuário possa logar imediatamente
  -- ========================================================================
  IF v_role IN ('nutritionist', 'trainer', 'student') THEN
    UPDATE auth.users
    SET email_confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = new.id;
  END IF;

  RETURN new;
END;
$$;

-- Recriar trigger apenas para garantir
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Limpeza Específica Imediata para destravar o caso atual
DELETE FROM auth.users WHERE email = 'canaltop98@gmail.com';
DELETE FROM public.users_nutricionista WHERE email = 'canaltop98@gmail.com';
DELETE FROM public.users_personal WHERE email = 'canaltop98@gmail.com';
DELETE FROM public.users_alunos WHERE email = 'canaltop98@gmail.com';

COMMIT;
