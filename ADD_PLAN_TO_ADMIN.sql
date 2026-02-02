-- Adicionar coluna plano_mensal na tabela users_adm
ALTER TABLE public.users_adm 
ADD COLUMN IF NOT EXISTS plano_mensal TEXT;

-- Atualizar a função handle_new_user para capturar o plano do metadata
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
  v_plano TEXT; -- Nova variável
BEGIN
  -- Extrair e validar dados essenciais
  v_role := new.raw_user_meta_data->>'role';
  
  IF v_role IS NULL THEN
    RAISE WARNING 'Usuário criado sem role: %', new.id;
    RETURN new;
  END IF;

  v_name := new.raw_user_meta_data->>'name';
  v_academia := new.raw_user_meta_data->>'academia';
  v_cnpj_academia := new.raw_user_meta_data->>'cnpj_academia';
  v_phone := new.raw_user_meta_data->>'phone';
  v_plano := new.raw_user_meta_data->>'plano_mensal'; -- Captura o plano
  
  -- Admin ID é crítico. Se falhar conversão, ignorar se for admin
  BEGIN
    v_created_by_admin_id := (new.raw_user_meta_data->>'created_by_admin_id')::UUID;
  EXCEPTION WHEN OTHERS THEN
    IF v_role IN ('nutritionist', 'trainer', 'student') THEN
        RAISE EXCEPTION 'ID do Administrador inválido ou ausente no cadastro.';
    END IF;
  END;

  -- INSERÇÕES STRICT

  IF v_role = 'admin' THEN
    INSERT INTO public.users_adm (id, email, nome, academia, cnpj_academia, telefone, plano_mensal)
    VALUES (new.id, new.email, v_name, v_academia, v_cnpj_academia, v_phone, v_plano)
    ON CONFLICT (id) DO UPDATE SET
      nome = EXCLUDED.nome,
      academia = EXCLUDED.academia,
      cnpj_academia = EXCLUDED.cnpj_academia,
      plano_mensal = EXCLUDED.plano_mensal;
      
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

  -- Se for um desses roles, CONFIRMAR EMAIL AUTOMATICAMENTE
  IF v_role IN ('nutritionist', 'trainer', 'student') THEN
    UPDATE auth.users
    SET email_confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = new.id;
  END IF;

  RETURN new;
END;
$$;
