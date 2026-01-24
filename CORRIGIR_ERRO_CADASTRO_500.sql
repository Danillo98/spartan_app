-- CORRIGIR_ERRO_CADASTRO_500.sql
-- =============================================================================
-- SCRIPT DE CORREÇÃO DE ERRO 500 NO CADASTRO (DATA CLEANUP)
-- =============================================================================

-- Este script resolve o erro "Database error saving new user" causado geralmente
-- por conflitos de email em cadastros antigos (órfãos) que impedem novos cadastros.

BEGIN;

-- 1. LIMPEZA DE DADOS ÓRFÃOS (CRÍTICO)
-- Remove registros nas tabelas públicas que NÃO têm correspondente em auth.users.
-- Isso libera emails que estão "presos" em cadastros mal sucedidos anteriores.

DELETE FROM public.users_nutricionista 
WHERE id NOT IN (SELECT id FROM auth.users);

DELETE FROM public.users_personal 
WHERE id NOT IN (SELECT id FROM auth.users);

DELETE FROM public.users_alunos 
WHERE id NOT IN (SELECT id FROM auth.users);

DELETE FROM public.users_adm 
WHERE id NOT IN (SELECT id FROM auth.users);

-- 2. REFORÇO DA FUNÇÃO handle_new_user
-- Atualiza a função para garantir tratamento correto de IDs e Roles

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
  -- Extrair metadados
  v_role := new.raw_user_meta_data->>'role';
  
  IF v_role IS NULL THEN
    RAISE WARNING 'Usuário criado sem role: %', new.id;
    RETURN new;
  END IF;

  v_name := new.raw_user_meta_data->>'name';
  v_academia := new.raw_user_meta_data->>'academia';
  v_cnpj_academia := new.raw_user_meta_data->>'cnpj_academia';
  v_phone := new.raw_user_meta_data->>'phone';
  
  -- Tratamento seguro para conversão de UUID
  BEGIN
    v_created_by_admin_id := (new.raw_user_meta_data->>'created_by_admin_id')::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_created_by_admin_id := NULL;
  END;

  -- Validação de Admin ID obrigatório para sub-usuários
  IF v_role IN ('nutritionist', 'trainer', 'student') AND v_created_by_admin_id IS NULL THEN
      RAISE EXCEPTION 'ID do Administrador inválido ou ausente no cadastro. Verifique se o Admin está logado corretamente.';
  END IF;

  -- Inserções nas tabelas públicas
  IF v_role = 'admin' THEN
    -- Admin permite atualização se já existir (para casos de re-auth)
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

  -- Auto-confirmação de Email para sub-usuários (Simplificação do fluxo)
  IF v_role IN ('nutritionist', 'trainer', 'student') THEN
    UPDATE auth.users
    SET email_confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = new.id;
  END IF;

  RETURN new;
END;
$$;

COMMIT;

-- Mensagem de confirmação
DO $$
BEGIN
  RAISE NOTICE 'Limpeza de dados órfãos realizada com sucesso.';
  RAISE NOTICE 'Função handle_new_user atualizada.';
END $$;
