-- TRIGGER V4 (ULTIMATE) - Extrai TUDO do Metadata
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
  
  -- Campos adicionais para evitar erro NOT NULL
  meta_nome text;
  meta_telefone text;
  
  -- Campos Pessoais (Correção Final)
  meta_cpf text;
  meta_endereco text;
BEGIN
  -- TENTA PEGAR DADOS
  user_role := new.raw_user_meta_data->>'role';
  meta_plano := new.raw_user_meta_data->>'plano_mensal';
  meta_cnpj := new.raw_user_meta_data->>'cnpj_academia';
  meta_academia := new.raw_user_meta_data->>'academia';
  meta_nome := new.raw_user_meta_data->>'name';
  meta_telefone := new.raw_user_meta_data->>'phone';
  
  -- Novos campos mapeados no AuthService
  meta_cpf := new.raw_user_meta_data->>'cpf_pessoal';
  meta_endereco := new.raw_user_meta_data->>'endereco_pessoal';

  -- LOG DE ENTRADA
  INSERT INTO public.app_logs (message) 
  VALUES ('Trigger V4 START. ID: ' || new.id || 
          '. Plano: ' || coalesce(meta_plano, 'NULO') ||
          '. Nome: ' || coalesce(meta_nome, 'NULO') ||
          '. CPF: ' || coalesce(meta_cpf, 'NULO'));

  -- CORREÇÃO DE NULO (Plano)
  IF meta_plano IS NULL OR meta_plano = '' OR meta_plano = 'null' THEN
     meta_plano := 'Prata';
  END IF;

  -- INSERÇÃO
  IF user_role = 'admin' THEN
    -- Inserir APENAS se tiver CNPJ (obrigatório)
    IF meta_cnpj IS NOT NULL AND meta_cnpj <> '' THEN
        insert into public.users_adm (id, email, plano_mensal, cnpj_academia, academia, nome, telefone, email_verified, cpf, endereco)
        values (
            new.id, 
            new.email, 
            meta_plano, 
            meta_cnpj, 
            meta_academia, 
            coalesce(meta_nome, 'Administrador'), 
            coalesce(meta_telefone, ''), 
            true,
            coalesce(meta_cpf, ''),
            coalesce(meta_endereco, '')
        )
        ON CONFLICT (id) DO UPDATE
        SET 
            plano_mensal = EXCLUDED.plano_mensal,
            cnpj_academia = EXCLUDED.cnpj_academia,
            academia = EXCLUDED.academia,
            nome = EXCLUDED.nome,
            cpf = EXCLUDED.cpf,
            endereco = EXCLUDED.endereco;
        
        INSERT INTO public.app_logs (message) VALUES ('Success: Users_adm inserted/updated (V4 with CPF/Address).');
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
  INSERT INTO public.app_logs (message) VALUES ('CRITICAL ERROR IN TRIGGER V4: ' || SQLERRM);
  RETURN new;
END;
$$;
