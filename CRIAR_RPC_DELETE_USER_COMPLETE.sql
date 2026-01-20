-- =============================================================================
-- DELETE USER COMPLETE (AUTH + PUBLIC)
-- =============================================================================
-- Função para deletar um usuário completamente (do Auth e das Tabelas Públicas).
-- Necessária porque o Admin do app não tem permissão direta de 'supabase.auth.admin'.

CREATE OR REPLACE FUNCTION delete_user_complete(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER -- Roda com as permissões do criador (postgres/admin)
SET search_path = public, auth -- Contexto necessário
AS $$
DECLARE
    requesting_user_id UUID;
BEGIN
    requesting_user_id := auth.uid();

    -- 1. Verifica segurança: Somente um Admin logado pode executar
    IF NOT EXISTS (SELECT 1 FROM public.users_adm WHERE id = requesting_user_id) THEN
        RAISE EXCEPTION 'Acesso negado: Apenas administradores podem excluir usuários.';
    END IF;

    -- 2. Evita auto-exclusão acidental via RPC (opcional)
    IF requesting_user_id = target_user_id THEN
        RAISE EXCEPTION 'Não é possível excluir a sua própria conta por esta função.';
    END IF;

    -- 3. Remove registros das tabelas públicas (Garante limpeza mesmo sem FK)
    DELETE FROM public.users_nutricionista WHERE id = target_user_id;
    DELETE FROM public.users_personal WHERE id = target_user_id;
    DELETE FROM public.users_alunos WHERE id = target_user_id;
    -- Se necessário deletar outro admin:
    DELETE FROM public.users_adm WHERE id = target_user_id;

    -- 4. Remove do Auth (Authentication)
    DELETE FROM auth.users WHERE id = target_user_id;

    -- Se não der erro, commita.
END;
$$;

SELECT 'Função delete_user_complete criada com sucesso.' as status;
