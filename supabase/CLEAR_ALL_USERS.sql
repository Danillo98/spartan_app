-- ATENÇÃO: VERSÃO DEFINITIVA V6 (BASEADA NA IMAGEM)
-- ESTE SCRIPT APAGA TODOS OS USUÁRIOS E DADOS RELACIONADOS DE FORMA SEGURA
-- Execute no SQL Editor do Supabase

-- 1. Apagar tabelas dependentes (Folhas da árvore e logs)
-- Ordem: Primeiro as que não dependem de nada ou são dependências de baixo nível

DELETE FROM public.workout_exercises;      -- Exercícios dentro dos treinos (nome correto visto na imagem)
DELETE FROM public.exercises;              -- (Mantendo por segurança caso exista duplicidade)

DELETE FROM public.meals;                  -- Refeições
DELETE FROM public.diet_days;              -- Dias de dieta

DELETE FROM public.workout_days;           -- Dias de treino

-- Apagar tabelas de relacionamento e logs
DELETE FROM public.physical_assessments;   -- Avaliações físicas
DELETE FROM public.appointments;           -- Agendamentos
DELETE FROM public.notices;                -- Avisos
DELETE FROM public.training_sessions;      -- Sessões de treino

DELETE FROM public.financial_transactions; -- Transações financeiras (nome correto visto na imagem)
DELETE FROM public.user_fcm_tokens;        -- Tokens FCM (nome correto visto na imagem)
DELETE FROM public.email_verification_codes;-- Códigos de verificação
DELETE FROM public.login_attempts;         -- Tentativas de login
DELETE FROM public.audit_logs;             -- Logs de auditoria (provavelmente tem ref para usuários)
DELETE FROM public.active_sessions;        -- Sessões ativas

-- 2. Apagar tabelas principais de negócio
DELETE FROM public.diets;                  -- Dietas
DELETE FROM public.workouts;               -- Treinos

-- 3. Apagar perfis específicos de usuários
DELETE FROM public.users_adm;
DELETE FROM public.users_nutricionista;
DELETE FROM public.users_personal;
DELETE FROM public.users_alunos;

-- 4. Apagar tabela pública de usuários (Vínculo principal)
DELETE FROM public.users;                  -- (Não aparece na imagem mas é padrão do sistema se syncado com auth, ou foi omitida)

-- 5. Apagar usuários do sistema de autenticação (A raiz de tudo)
DELETE FROM auth.users;

-- Confirmação
SELECT 'Limpeza TOTAL realizada com sucesso.' as status;
