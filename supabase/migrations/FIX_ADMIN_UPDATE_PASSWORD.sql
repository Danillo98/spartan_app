-- ============================================
-- CORREÇÃO: admin_update_password
-- ============================================
-- Atualiza a função para verificar se o usuário é Admin
-- consultando a tabela users_adm em vez de public.users

DROP FUNCTION IF EXISTS public.admin_update_password(uuid, text);

CREATE OR REPLACE FUNCTION public.admin_update_password(
    target_user_id uuid,
    new_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_admin boolean;
BEGIN
    -- Verificar se o usuário atual é administrador
    -- Consulta users_adm em vez de public.users
    SELECT EXISTS (
        SELECT 1 FROM public.users_adm 
        WHERE id = auth.uid()
    ) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Apenas administradores podem alterar senhas de outros usuários.'
        );
    END IF;
    
    -- Validar senha (mínimo 6 caracteres)
    IF length(new_password) < 6 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'A senha deve ter no mínimo 6 caracteres.'
        );
    END IF;
    
    -- Verificar se o usuário alvo existe
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = target_user_id) THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Usuário não encontrado.'
        );
    END IF;
    
    -- Atualizar senha no auth.users
    UPDATE auth.users
    SET 
        encrypted_password = crypt(new_password, gen_salt('bf')),
        updated_at = now()
    WHERE id = target_user_id;
    
    -- Verificar se a atualização foi bem-sucedida
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Erro ao atualizar senha.'
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Senha alterada com sucesso!'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false, 
        'message', 'Erro ao alterar senha: ' || SQLERRM
    );
END;
$$;

-- Permissões
GRANT EXECUTE ON FUNCTION public.admin_update_password(uuid, text) TO authenticated;

-- Reload
NOTIFY pgrst, 'reload schema';

SELECT '✅ Função admin_update_password corrigida para usar users_adm.' as status;
