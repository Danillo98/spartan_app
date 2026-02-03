-- CORREÇÃO DA TRIGGER DE CRIAÇÃO DE USUÁRIO
-- Objetivo: Garantir que o campo 'plano_mensal' seja gravado na tabela users_adm
-- quando o usuário é criado via Auth (SignUp).

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  is_admin boolean;
  user_role text;
  meta_plano text;
BEGIN
  -- Extrair role e plano dos metadados
  user_role := new.raw_user_meta_data->>'role';
  meta_plano := new.raw_user_meta_data->>'plano_mensal';

  -- Se o plano vier nulo, definir padrão 'Prata' apenas para admins
  IF meta_plano IS NULL OR meta_plano = '' THEN
     meta_plano := 'Prata';
  END IF;

  -- Verifica se é admin
  IF user_role = 'admin' THEN
    insert into public.users_adm (id, email, nome, telefone, cnpj_academia, academia, cpf, endereco, plano_mensal)
    values (
      new.id,
      new.email,
      new.raw_user_meta_data->>'name',
      new.raw_user_meta_data->>'phone',
      new.raw_user_meta_data->>'cnpj_academia',
      new.raw_user_meta_data->>'academia',
      new.raw_user_meta_data->>'cpf',       -- CPF pessoal (se houver, senao null)
      new.raw_user_meta_data->>'endereco',  -- Endereço (se houver, senao null)
      meta_plano                             -- AQUI: Agora garantimos que o plano entra!
    )
    ON CONFLICT (id) DO UPDATE SET
      plano_mensal = EXCLUDED.plano_mensal, -- Se já existir, atualiza o plano
      nome = EXCLUDED.nome,
      telefone = EXCLUDED.telefone;

  ELSIF user_role = 'nutritionist' THEN
    insert into public.users_nutricionista (id, email, nome, telefone, id_academia, cnpj_academia)
    values (
        new.id, 
        new.email, 
        new.raw_user_meta_data->>'name', 
        new.raw_user_meta_data->>'phone',
        (new.raw_user_meta_data->>'id_academia')::uuid,
        new.raw_user_meta_data->>'cnpj_academia'
    );

  ELSIF user_role = 'trainer' THEN
    insert into public.users_personal (id, email, nome, telefone, id_academia, cnpj_academia)
    values (
        new.id, 
        new.email, 
        new.raw_user_meta_data->>'name', 
        new.raw_user_meta_data->>'phone',
        (new.raw_user_meta_data->>'id_academia')::uuid,
        new.raw_user_meta_data->>'cnpj_academia'
    );

  ELSIF user_role = 'student' OR user_role IS NULL THEN
    insert into public.users_alunos (id, email, nome, telefone, id_academia, cnpj_academia, payment_due_day)
    values (
        new.id, 
        new.email, 
        new.raw_user_meta_data->>'name', 
        new.raw_user_meta_data->>'phone',
        (new.raw_user_meta_data->>'id_academia')::uuid,
        new.raw_user_meta_data->>'cnpj_academia',
        (new.raw_user_meta_data->>'paymentDueDay')::int
    );
  END IF;

  return new;
END;
$$;
