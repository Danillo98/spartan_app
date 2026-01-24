-- =============================================================================
-- SOLUÇÃO DEFINITIVA V4: PRESERVAÇÃO DE DADOS & CASCADE INTELIGENTE
-- =============================================================================

-- Este script ajusta as Foreign Keys para atender às regras de negócio:
-- 1. Aluno deletado -> Tudo dele é apagado (CASCADE).
-- 2. Profissional deletado -> Dados mantidos, campo do profissional vira NULL (SET NULL).

-- =============================================================================
-- PARTE 1: CORREÇÃO DO ERRO ATUAL (Training Sessions)
-- =============================================================================
DO $$ BEGIN
    -- Garantir que training_sessions apague se o aluno for apagado
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'training_sessions_student_id_fkey') THEN
        ALTER TABLE public.training_sessions DROP CONSTRAINT training_sessions_student_id_fkey;
        ALTER TABLE public.training_sessions ADD CONSTRAINT training_sessions_student_id_fkey 
            FOREIGN KEY (student_id) REFERENCES public.users_alunos(id) ON DELETE CASCADE;
    END IF;
END $$;

-- =============================================================================
-- PARTE 2: CONFIGURAR PRESERVAÇÃO PARA PROFISSIONAIS (SET NULL)
-- =============================================================================

-- TREINOS (WORKOUTS)
-- Se o Personal sair, o treino fica. Removemos NOT NULL do personal_id e setamos FK para SET NULL.
DO $$ BEGIN
    -- 1. Permitir NULL na coluna personal_id (se existir)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workouts' AND column_name = 'personal_id') THEN
        ALTER TABLE public.workouts ALTER COLUMN personal_id DROP NOT NULL;
        
        -- 2. Atualizar FK para SET NULL
        IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'workouts_personal_id_fkey') THEN
            ALTER TABLE public.workouts DROP CONSTRAINT workouts_personal_id_fkey;
            ALTER TABLE public.workouts ADD CONSTRAINT workouts_personal_id_fkey 
                FOREIGN KEY (personal_id) REFERENCES public.users_personal(id) ON DELETE SET NULL;
        END IF;
    END IF;

    -- Garantir CASCADE para o ALUNO (student_id)
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'workouts_student_id_fkey') THEN
        ALTER TABLE public.workouts DROP CONSTRAINT workouts_student_id_fkey;
        ALTER TABLE public.workouts ADD CONSTRAINT workouts_student_id_fkey 
            FOREIGN KEY (student_id) REFERENCES public.users_alunos(id) ON DELETE CASCADE;
    END IF;
END $$;

-- DIETAS (DIETS)
-- Se Nutri sair, dieta fica.
DO $$ BEGIN
    -- 1. Permitir NULL na coluna nutritionist_id
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'diets' AND column_name = 'nutritionist_id') THEN
        ALTER TABLE public.diets ALTER COLUMN nutritionist_id DROP NOT NULL;

        -- 2. Atualizar FK para SET NULL
        IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'diets_nutritionist_id_fkey') THEN
            ALTER TABLE public.diets DROP CONSTRAINT diets_nutritionist_id_fkey;
            ALTER TABLE public.diets ADD CONSTRAINT diets_nutritionist_id_fkey 
                FOREIGN KEY (nutritionist_id) REFERENCES public.users_nutricionista(id) ON DELETE SET NULL;
        END IF;
    END IF;

    -- Garantir CASCADE para o ALUNO
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'diets_student_id_fkey') THEN
        ALTER TABLE public.diets DROP CONSTRAINT diets_student_id_fkey;
        ALTER TABLE public.diets ADD CONSTRAINT diets_student_id_fkey 
            FOREIGN KEY (student_id) REFERENCES public.users_alunos(id) ON DELETE CASCADE;
    END IF;
END $$;

-- AVALIAÇÕES FÍSICAS (PHYSICAL_ASSESSMENTS)
-- Assumindo que a tabela existe conforme imagem.
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'physical_assessments') THEN
        -- Tentar descobrir o nome da coluna do profissional (pode ser nutritionist_id ou professional_id)
        -- Aqui vamos tentar nutritionist_id pois geralmente quem faz é nutri.
        
        -- CASCADE para Aluno
        IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'physical_assessments_student_id_fkey') THEN
            ALTER TABLE public.physical_assessments DROP CONSTRAINT physical_assessments_student_id_fkey;
            ALTER TABLE public.physical_assessments ADD CONSTRAINT physical_assessments_student_id_fkey 
                FOREIGN KEY (student_id) REFERENCES public.users_alunos(id) ON DELETE CASCADE;
        END IF;

        -- SET NULL para Nutricionista (se a coluna existir e tiver FK)
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'physical_assessments' AND column_name = 'nutritionist_id') THEN
            ALTER TABLE public.physical_assessments ALTER COLUMN nutritionist_id DROP NOT NULL;
            
            IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'physical_assessments_nutritionist_id_fkey') THEN
                ALTER TABLE public.physical_assessments DROP CONSTRAINT physical_assessments_nutritionist_id_fkey;
                ALTER TABLE public.physical_assessments ADD CONSTRAINT physical_assessments_nutritionist_id_fkey 
                    FOREIGN KEY (nutritionist_id) REFERENCES public.users_nutricionista(id) ON DELETE SET NULL;
            END IF;
        END IF;
    END IF;
END $$;

-- TABELA NOTICES (AVISOS)
-- CASCADE para Aluno (target)
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'notices_target_student_id_fkey') THEN
        ALTER TABLE public.notices DROP CONSTRAINT notices_target_student_id_fkey;
        ALTER TABLE public.notices ADD CONSTRAINT notices_target_student_id_fkey 
            FOREIGN KEY (target_student_id) REFERENCES public.users_alunos(id) ON DELETE CASCADE;
    END IF;
END $$;

-- =============================================================================
-- PARTE 3: RPC FINAL (SIMPLIFICADA)
-- =============================================================================
-- Agora que configuramos CASCADES e SET NULLS no banco, a função pode ser mais simples.
-- Ela foca em disparar os deletes. O banco cuida do resto.

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

    -- LIMPEZA MANUAL DE TABELAS SENSÍVEIS (Que podem não ter FK ou serem complexas)
    
    -- Financeiro (related_user_id) - Delete manual seguro
    DELETE FROM public.financial_transactions WHERE related_user_id = target_user_id;

    -- Notificações e Logs (Geralmente não travam, mas é bom limpar)
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'notifications') THEN
        DELETE FROM public.notifications WHERE user_id = target_user_id;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'notices_read') THEN
        DELETE FROM public.notices_read WHERE user_id = target_user_id;
    END IF;

    -- DELETE DOS PERFIS (Dispara os CASCADES e SET NULLS configurados acima)
    DELETE FROM public.users_nutricionista WHERE id = target_user_id;
    DELETE FROM public.users_personal WHERE id = target_user_id;
    DELETE FROM public.users_alunos WHERE id = target_user_id;
    DELETE FROM public.users_adm WHERE id = target_user_id;

    -- DELETE DO AUTH (Final)
    DELETE FROM auth.users WHERE id = target_user_id;
END;
$$;
