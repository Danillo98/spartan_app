-- =============================================================================
-- REFATORAÇÃO DE CADASTRO E AUTENTICAÇÃO
-- =============================================================================

-- 1. TRIGGER PARA MANIPULAR NOVO USUÁRIO (HANDLE_NEW_USER)
-- Essa trigger é ativada sempre que um usuário é criado no auth.users
-- Ela garante que os dados vão para a tabela pública correta.

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
  -- Extrair dados dos metadados (raw_user_meta_data)
  v_role := new.raw_user_meta_data->>'role';
  v_name := new.raw_user_meta_data->>'name';
  v_academia := new.raw_user_meta_data->>'academia';
  v_cnpj_academia := new.raw_user_meta_data->>'cnpj_academia';
  v_phone := new.raw_user_meta_data->>'phone';
  
  -- Conversão de UUID seguro
  BEGIN
    v_created_by_admin_id := (new.raw_user_meta_data->>'created_by_admin_id')::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_created_by_admin_id := NULL;
  END;

  -- Se for admin se auto-cadastrando (sem created_by)
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

  RETURN new;
EXCEPTION
  WHEN OTHERS THEN
    -- Logar erro mas não falhar (para debug)
    RAISE WARNING 'Erro ao criar perfil público: %', SQLERRM;
    RETURN new;
END;
$$;

-- 2. RECRIAÇÃO DA TRIGGER NO AUTH.USERS
-- Precisamos garantir que ela exista.

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- 3. LIMPEZA DE INCONSISTÊNCIAS (OPCIONAL)
-- Remove registros públicos que não têm correspondente no Auth (Usuários fantasmas)
DELETE FROM public.users_nutricionista 
WHERE id NOT IN (SELECT id FROM auth.users);

DELETE FROM public.users_personal 
WHERE id NOT IN (SELECT id FROM auth.users);

DELETE FROM public.users_alunos 
WHERE id NOT IN (SELECT id FROM auth.users);

-- Nota: Não deletamos admins fantasmas por segurança, mas poderia ser feito.

