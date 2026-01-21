-- Script para LIMPEZA TOTAL do Banco de Dados (Público + Autenticação)
-- ATENÇÃO: Isso apagará TODOS os usuários e dados. Irreversível.
-- Execute este script no SQL Editor do painel do Supabase.

-- 1. Apagar tabelas dependentes (Logs e Itens)
DELETE FROM public.workout_exercises;      
DELETE FROM public.exercises; 
DELETE FROM public.meals;
DELETE FROM public.diet_days;
DELETE FROM public.workout_days;

-- 2. Apagar tabelas de relacionamento e logs
DELETE FROM public.physical_assessments;
DELETE FROM public.appointments;
DELETE FROM public.notices;
DELETE FROM public.training_sessions;
-- Verifica se as tabelas existem para evitar erro caso alguma não tenha sido criada ainda
DELETE FROM public.financial_transactions;
DELETE FROM public.user_fcm_tokens;
DELETE FROM public.email_verification_codes;
DELETE FROM public.login_attempts;
DELETE FROM public.audit_logs;
DELETE FROM public.active_sessions;

-- 3. Apagar tabelas principais
DELETE FROM public.diets;
DELETE FROM public.workouts;

-- 4. Apagar perfis (Tabelas públicas de usuários)
-- É importante apagar estas antes de auth.users para evitar violação de FK se não estiver configurado CASCADE
DELETE FROM public.users_adm;
DELETE FROM public.users_nutricionista;
DELETE FROM public.users_personal;
DELETE FROM public.users_alunos;

-- 5. Apagar usuários de Autenticação (Supabase Auth)
-- Isso remove o login, senha e metadados de autenticação do sistema do Supabase
DELETE FROM auth.users;

SELECT 'Limpeza TOTAL (Dados + Auth) realizada com sucesso.' as status;
