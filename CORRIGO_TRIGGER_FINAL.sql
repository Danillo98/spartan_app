-- CORRIGO_TRIGGER_FINAL.sql
-- Adiciona coluna id_academia se não existir e atualiza o Trigger para populá-la

-- 1. Garantir que as colunas id_academia existam nas tabelas
ALTER TABLE public.users_nutricionista ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id);
ALTER TABLE public.users_personal ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id);
ALTER TABLE public.users_alunos ADD COLUMN IF NOT EXISTS id_academia UUID REFERENCES public.users_adm(id);

-- 2. Atualizar a função handle_new_user para preencher id_academia
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
  v_id_academia UUID; -- Nova variável para garantir o vínculo
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
    -- Se foi criado por um admin, o id_academia é o próprio ID do admin
    v_id_academia := v_created_by_admin_id;
  EXCEPTION WHEN OTHERS THEN
    v_created_by_admin_id := NULL;
    v_id_academia := NULL;
  END;

  IF v_role IS NULL THEN
    RETURN new;
  END IF;

  -- 2. AUTO-LIMPEZA DE ORFÃOS
  DELETE FROM public.users_nutricionista WHERE email = new.email;
  DELETE FROM public.users_personal WHERE email = new.email;
  DELETE FROM public.users_alunos WHERE email = new.email;

  -- 3. INSERÇÃO (Agora incluindo id_academia)
  IF v_role = 'admin' THEN
    -- Admin é a própria academia
    INSERT INTO public.users_adm (id, email, nome, academia, cnpj_academia, telefone)
    VALUES (new.id, new.email, v_name, v_academia, v_cnpj_academia, v_phone)
    ON CONFLICT (id) DO UPDATE SET
      nome = EXCLUDED.nome,
      academia = EXCLUDED.academia,
      cnpj_academia = EXCLUDED.cnpj_academia;
      
  ELSIF v_role = 'nutritionist' THEN
    INSERT INTO public.users_nutricionista (id, email, nome, academia, cnpj_academia, telefone, created_by_admin_id, id_academia)
    VALUES (new.id, new.email, v_name, v_academia, v_cnpj_academia, v_phone, v_created_by_admin_id, v_id_academia);
    
  ELSIF v_role = 'trainer' THEN
    INSERT INTO public.users_personal (id, email, nome, academia, cnpj_academia, telefone, created_by_admin_id, id_academia)
    VALUES (new.id, new.email, v_name, v_academia, v_cnpj_academia, v_phone, v_created_by_admin_id, v_id_academia);
    
  ELSIF v_role = 'student' THEN
    v_payment_due_day := (new.raw_user_meta_data->>'paymentDueDay')::INTEGER;
    INSERT INTO public.users_alunos (id, email, nome, academia, cnpj_academia, telefone, created_by_admin_id, id_academia, payment_due_day)
    VALUES (new.id, new.email, v_name, v_academia, v_cnpj_academia, v_phone, v_created_by_admin_id, v_id_academia, v_payment_due_day);
  END IF;

  -- 4. CONFIRMAÇÃO AUTOMÁTICA
  IF v_role IN ('nutritionist', 'trainer', 'student') THEN
    UPDATE auth.users
    SET email_confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = new.id;
  END IF;

  RETURN new;
END;
$$;

SELECT 'Trigger atualizada com suporte a id_academia e colunas criadas se necessário.' as status;
