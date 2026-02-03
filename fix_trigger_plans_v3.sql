-- LOGS TABLE (Garantir que existe)
CREATE TABLE IF NOT EXISTS public.app_logs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    message text,
    created_at timestamptz DEFAULT now()
);

-- TRIGGER ROBUSTA (Com CNPJ e Academia)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  user_role text;
  meta_plano text;
  meta_cnpj text;
  meta_academia text;
BEGIN
  -- TENTA PEGAR DADOS
  user_role := new.raw_user_meta_data->>'role';
  meta_plano := new.raw_user_meta_data->>'plano_mensal';
  meta_cnpj := new.raw_user_meta_data->>'cnpj_academia';
  meta_academia := new.raw_user_meta_data->>'academia';

  -- LOG DE ENTRADA
  INSERT INTO public.app_logs (message) 
  VALUES ('Trigger V3 START. ID: ' || new.id || 
          '. Role: ' || coalesce(user_role, 'NULO') || 
          '. Plano: ' || coalesce(meta_plano, 'NULO') ||
          '. CNPJ: ' || coalesce(meta_cnpj, 'NULO'));

  -- CORREÇÃO DE NULO (Plano)
  IF meta_plano IS NULL OR meta_plano = '' OR meta_plano = 'null' THEN
     meta_plano := 'Prata';
  END IF;

  -- INSERÇÃO
  IF user_role = 'admin' THEN
    -- Inserir APENAS se tiver CNPJ (obrigatório)
    IF meta_cnpj IS NOT NULL AND meta_cnpj <> '' THEN
        insert into public.users_adm (id, email, plano_mensal, cnpj_academia, academia)
        values (new.id, new.email, meta_plano, meta_cnpj, meta_academia)
        ON CONFLICT (id) DO UPDATE
        SET 
            plano_mensal = EXCLUDED.plano_mensal,
            cnpj_academia = EXCLUDED.cnpj_academia,
            academia = EXCLUDED.academia;
        
        INSERT INTO public.app_logs (message) VALUES ('Success: Users_adm inserted/updated.');
    ELSE
        INSERT INTO public.app_logs (message) VALUES ('ERROR: CNPJ is missing. Cannot insert into users_adm.');
    END IF;
  
  ELSIF user_role = 'student' THEN
    insert into public.users_alunos (id, email, created_by_admin_id, id_academia)
    values (new.id, new.email, (new.raw_user_meta_data->>'created_by_admin_id')::uuid, (new.raw_user_meta_data->>'id_academia')::uuid);
  ELSIF user_role = 'nutritionist' THEN
    insert into public.users_nutricionista (id, email, created_by_admin_id, id_academia)
    values (new.id, new.email, (new.raw_user_meta_data->>'created_by_admin_id')::uuid, (new.raw_user_meta_data->>'id_academia')::uuid);
  ELSIF user_role = 'trainer' THEN
    insert into public.users_personal (id, email, created_by_admin_id, id_academia)
    values (new.id, new.email, (new.raw_user_meta_data->>'created_by_admin_id')::uuid, (new.raw_user_meta_data->>'id_academia')::uuid);
  END IF;

  return new;
EXCEPTION WHEN OTHERS THEN
  INSERT INTO public.app_logs (message) VALUES ('CRITICAL ERROR IN TRIGGER: ' || SQLERRM);
  RETURN new;
END;
$$;
