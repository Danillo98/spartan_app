-- ============================================
-- FUNÇÃO: admin_update_user_credentials
-- ============================================
-- Permite que o Admin atualize email e/ou senha de qualquer usuário
-- Atualiza tanto em auth.users quanto na tabela pública correspondente

DROP FUNCTION IF EXISTS public.admin_update_user_credentials(uuid, text, text);

CREATE OR REPLACE FUNCTION public.admin_update_user_credentials(
    target_user_id uuid,
    new_email text DEFAULT NULL,
    new_password text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_admin boolean;
    v_table_name text;
BEGIN
    -- 1. Verificar se o usuário atual é administrador
    SELECT EXISTS (
        SELECT 1 FROM public.users_adm 
        WHERE id = auth.uid()
    ) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Apenas administradores podem alterar credenciais de outros usuários.'
        );
    END IF;
    
    -- 2. Verificar se o usuário alvo existe
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = target_user_id) THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Usuário não encontrado.'
        );
    END IF;
    
    -- 3. Validar senha (se fornecida)
    IF new_password IS NOT NULL AND length(new_password) < 6 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'A senha deve ter no mínimo 6 caracteres.'
        );
    END IF;
    
    -- 4. Atualizar auth.users
    IF new_email IS NOT NULL AND new_password IS NOT NULL THEN
        -- Atualizar email E senha
        UPDATE auth.users
        SET 
            email = new_email,
            encrypted_password = crypt(new_password, gen_salt('bf')),
            updated_at = now(),
            email_confirmed_at = now() -- Confirmar email automaticamente
        WHERE id = target_user_id;
        
    ELSIF new_email IS NOT NULL THEN
        -- Atualizar apenas email
        UPDATE auth.users
        SET 
            email = new_email,
            updated_at = now(),
            email_confirmed_at = now()
        WHERE id = target_user_id;
        
    ELSIF new_password IS NOT NULL THEN
        -- Atualizar apenas senha
        UPDATE auth.users
        SET 
            encrypted_password = crypt(new_password, gen_salt('bf')),
            updated_at = now()
        WHERE id = target_user_id;
    ELSE
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Nenhuma credencial fornecida para atualização.'
        );
    END IF;
    
    -- 5. Atualizar email na tabela pública correspondente (se fornecido)
    IF new_email IS NOT NULL THEN
        -- Descobrir em qual tabela o usuário está
        IF EXISTS (SELECT 1 FROM public.users_adm WHERE id = target_user_id) THEN
            UPDATE public.users_adm SET email = new_email WHERE id = target_user_id;
        ELSIF EXISTS (SELECT 1 FROM public.users_nutricionista WHERE id = target_user_id) THEN
            UPDATE public.users_nutricionista SET email = new_email WHERE id = target_user_id;
        ELSIF EXISTS (SELECT 1 FROM public.users_personal WHERE id = target_user_id) THEN
            UPDATE public.users_personal SET email = new_email WHERE id = target_user_id;
        ELSIF EXISTS (SELECT 1 FROM public.users_alunos WHERE id = target_user_id) THEN
            UPDATE public.users_alunos SET email = new_email WHERE id = target_user_id;
        END IF;
    END IF;
    
    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Credenciais atualizadas com sucesso!'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false, 
        'message', 'Erro ao atualizar credenciais: ' || SQLERRM
    );
END;
$$;

-- Permissões
GRANT EXECUTE ON FUNCTION public.admin_update_user_credentials(uuid, text, text) TO authenticated;

-- Reload
NOTIFY pgrst, 'reload schema';

SELECT '✅ Função admin_update_user_credentials criada. Atualiza email e senha em auth.users e tabelas públicas.' as status;
