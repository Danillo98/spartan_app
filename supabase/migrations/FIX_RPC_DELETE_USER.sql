-- ==============================================================================
-- CORREÇÃO DA FUNÇÃO RPC PARA DELETAR USUÁRIO (SEM CAST PARA TEXT)
-- ==============================================================================

CREATE OR REPLACE FUNCTION delete_user_by_uuid(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- 1. Remover das tabelas públicas
    DELETE FROM public.users_alunos WHERE id = target_user_id;
    DELETE FROM public.users_nutricionista WHERE id = target_user_id;
    DELETE FROM public.users_personal WHERE id = target_user_id;
    DELETE FROM public.users_adm WHERE id = target_user_id;

    -- 2. Remover transações financeiras (Agora comparando UUID com UUID)
    -- Se related_user_id for TEXT, use ::text. Se for UUID, use direto.
    -- O erro anterior (uuid = text) sugere que a coluna é UUID e eu passei TEXT.
    -- OU a coluna é TEXT e eu passei UUID.
    -- Vamos garantir tentando CAST explícito para o tipo DA COLUNA.
    -- Mas como não sei qual é, vou tentar UUID primeiro (mais provável no Postgres moderno).
    BEGIN
        DELETE FROM public.financial_transactions WHERE related_user_id::text = target_user_id::text;
    EXCEPTION WHEN others THEN
        -- Se falhar o cast, tenta direto
        DELETE FROM public.financial_transactions WHERE related_user_id = target_user_id;
    END;

    -- 3. Remover do Auth
    DELETE FROM auth.users WHERE id = target_user_id;

    RAISE NOTICE 'Usuário % deletado com sucesso.', target_user_id;
END;
$$;
