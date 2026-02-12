-- ==============================================================================
-- FUNÇÃO RPC PARA DELETAR USUÁRIO POR ID (REUTILIZÁVEL)
-- ==============================================================================

CREATE OR REPLACE FUNCTION delete_user_by_uuid(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER -- Roda com permissões de admin
AS $$
BEGIN
    -- 1. Remover das tabelas públicas
    DELETE FROM public.users_alunos WHERE id = target_user_id;
    DELETE FROM public.users_nutricionista WHERE id = target_user_id;
    DELETE FROM public.users_personal WHERE id = target_user_id;
    DELETE FROM public.users_adm WHERE id = target_user_id;

    -- 2. Remover transações financeiras órfãs
    DELETE FROM public.financial_transactions WHERE related_user_id = target_user_id::text;

    -- 3. Remover do Auth (Isso revoga o acesso imediatamente)
    DELETE FROM auth.users WHERE id = target_user_id;

    RAISE NOTICE 'Usuário % deletado com sucesso.', target_user_id;
END;
$$;
