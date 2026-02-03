-- Função para logar (opcional, cria tabela de logs se não existir)
CREATE TABLE IF NOT EXISTS public.app_logs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    message text,
    created_at timestamptz DEFAULT now()
);

-- Refazer a função da Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  user_role text;
  meta_plano text;
BEGIN
  -- Log para debug
  INSERT INTO public.app_logs (message) VALUES ('Trigger handle_new_user iniciada para ' || new.id);

  user_role := new.raw_user_meta_data->>'role';
  meta_plano := new.raw_user_meta_data->>'plano_mensal';

  INSERT INTO public.app_logs (message) VALUES ('Role: ' || coalesce(user_role, 'NULL') || ', Plano: ' || coalesce(meta_plano, 'NULL'));

  -- Default defensivo dentro do banco
  IF meta_plano IS NULL OR meta_plano = '' OR meta_plano = 'null' THEN
     meta_plano := 'Prata';
     INSERT INTO public.app_logs (message) VALUES ('Plano era nulo, forçado para Prata');
  END IF;

  IF user_role = 'admin' THEN
    insert into public.users_adm (id, email, plano_mensal)
    values (new.id, new.email, meta_plano)
    ON CONFLICT (id) DO UPDATE
    SET plano_mensal = EXCLUDED.plano_mensal; -- Garante atualização se já existir
    
    INSERT INTO public.app_logs (message) VALUES ('Admin inserido com plano: ' || meta_plano);
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
  INSERT INTO public.app_logs (message) VALUES ('ERRO NA TRIGGER: ' || SQLERRM);
  RETURN new;
END;
$$;

-- Recriar a Trigger (caso necessário)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
