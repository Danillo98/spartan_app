-- FUNÇÃO PARA ADMINISTRADOR ALTERAR SENHA DE QUALQUER USUÁRIO
-- Permite que o admin redefina senha sem enviar email

CREATE OR REPLACE FUNCTION public.admin_update_password(
    target_user_id uuid,
    new_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_admin_role text;
BEGIN
    -- Verificar se o usuário atual é administrador
    SELECT role INTO v_admin_role
    FROM public.users
    WHERE id = auth.uid();
    
    IF v_admin_role IS NULL OR v_admin_role != 'Administrador' THEN
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

-- Grant de execução para usuários autenticados
GRANT EXECUTE ON FUNCTION public.admin_update_password(uuid, text) TO authenticated;

-- Comentário da função
COMMENT ON FUNCTION public.admin_update_password(uuid, text) IS 
'Permite que administradores alterem a senha de qualquer usuário sem enviar email de confirmação.';
