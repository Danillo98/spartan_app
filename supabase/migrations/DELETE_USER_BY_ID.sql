-- ==============================================================================
-- SCRIPT PARA DELETAR USUÁRIO PELO AUTH UID
-- ==============================================================================

-- Substitua o ID abaixo pelo UID do usuário que deseja deletar
-- Exemplo: 'd0e9a6b0-0b1a-4b0e-9a6b-0b1a4b0e9a6b'

DO $$
DECLARE
    -- 👇 COLOQUE O ID DO USUÁRIO AQUI 👇
    target_user_id UUID := '00000000-0000-0000-0000-000000000000'; 
BEGIN
    IF target_user_id = '00000000-0000-0000-0000-000000000000' THEN
        RAISE EXCEPTION 'Por favor, substitua o target_user_id pelo ID real do usuário.';
    END IF;

    -- 1. Tentar deletar das tabelas públicas primeiro (Nutri, Personal, Aluno, Adm)
    -- Isso evita erros de Foreign Key caso o CASCADE não esteja configurado
    DELETE FROM public.users_alunos WHERE id = target_user_id;
    DELETE FROM public.users_nutricionista WHERE id = target_user_id;
    DELETE FROM public.users_personal WHERE id = target_user_id;
    DELETE FROM public.users_adm WHERE id = target_user_id;

    -- 2. Deletar transações financeiras órfãs deste usuário (opcional, mas recomendado para limpeza)
    DELETE FROM public.financial_transactions WHERE related_user_id = target_user_id::text;

    -- 3. Finalmente, deletar da tabela de autenticação
    DELETE FROM auth.users WHERE id = target_user_id;

    RAISE NOTICE 'Usuário % deletado com sucesso de todas as tabelas.', target_user_id;
END $$;
