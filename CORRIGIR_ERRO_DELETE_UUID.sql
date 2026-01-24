-- =============================================================================
-- CORREÇÃO FINAL V3: INCLUINDO TABELA 'NOTICES'
-- =============================================================================

-- 1. ADICIONAR CASCADE NAS TABELAS CONHECIDAS
-- Isso previne que o banco trave o delete.

-- Treinos
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'workouts_student_id_fkey') THEN
        ALTER TABLE public.workouts DROP CONSTRAINT workouts_student_id_fkey;
        ALTER TABLE public.workouts ADD CONSTRAINT workouts_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users_alunos(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Dietas
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'diets_student_id_fkey') THEN
        ALTER TABLE public.diets DROP CONSTRAINT diets_student_id_fkey;
        ALTER TABLE public.diets ADD CONSTRAINT diets_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users_alunos(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Avisos (Notices) - O NOVO VILÃO
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'notices_target_student_id_fkey') THEN
        ALTER TABLE public.notices DROP CONSTRAINT notices_target_student_id_fkey;
        ALTER TABLE public.notices ADD CONSTRAINT notices_target_student_id_fkey FOREIGN KEY (target_student_id) REFERENCES public.users_alunos(id) ON DELETE CASCADE;
    END IF;
END $$;


-- 2. RECONSTRUIR RPC COM LIMPEZA TOTAL
CREATE OR REPLACE FUNCTION delete_user_complete(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    requesting_user_id UUID;
BEGIN
    requesting_user_id := auth.uid();

    -- Segurança
    IF NOT EXISTS (SELECT 1 FROM public.users_adm WHERE id = requesting_user_id) THEN
        RAISE EXCEPTION 'Acesso negado: Apenas administradores podem excluir usuários.';
    END IF;

    IF requesting_user_id = target_user_id THEN
        RAISE EXCEPTION 'Não é possível excluir a sua própria conta.';
    END IF;

    -- =========================================================================
    -- LIMPEZA EXPLICITA (Para garantir que tudo vá embora)
    -- =========================================================================
    
    -- Financeiro
    DELETE FROM public.financial_transactions WHERE related_user_id = target_user_id;

    -- Avisos (Direcionados ao aluno) - A correção para o erro 23503
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'notices') THEN
        DELETE FROM public.notices WHERE target_student_id = target_user_id;
    END IF;

    -- Avisos Lidos
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'notices_read') THEN
        DELETE FROM public.notices_read WHERE user_id = target_user_id;
    END IF;

    -- Notificações
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'notifications') THEN
        DELETE FROM public.notifications WHERE user_id = target_user_id;
    END IF;

    -- Avaliações e Fotos
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'student_evolution') THEN
        DELETE FROM public.student_evolution WHERE student_id = target_user_id;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'student_photos') THEN
        DELETE FROM public.student_photos WHERE student_id = target_user_id;
    END IF;

    -- Dietas e Treinos (Embora o Cascade resolva, forçamos para garantir)
    DELETE FROM public.diets WHERE student_id = target_user_id;
    DELETE FROM public.workouts WHERE student_id = target_user_id;

    -- Tabelas de Perfil (Delete final das tabelas públicas)
    DELETE FROM public.users_nutricionista WHERE id = target_user_id;
    DELETE FROM public.users_personal WHERE id = target_user_id;
    DELETE FROM public.users_alunos WHERE id = target_user_id;
    DELETE FROM public.users_adm WHERE id = target_user_id;

    -- Auth (Delete do usuário do sistema)
    DELETE FROM auth.users WHERE id = target_user_id;
END;
$$;
