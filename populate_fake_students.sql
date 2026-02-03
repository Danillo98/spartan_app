-- Script FINAL V3 para gerar 199 Alunos Fakes
-- Baseado na imagem das colunas enviada pelo usuário
-- Academia ID: 7282b7de-0c07-40b1-84f4-70e905300a14

DO $$
DECLARE
    i INT;
    academia_id UUID := '7282b7de-0c07-40b1-84f4-70e905300a14';
    new_user_id UUID;
    fake_email TEXT;
BEGIN
    FOR i IN 1..199 LOOP
        new_user_id := gen_random_uuid();
        fake_email := 'aluno.fake.' || i || '@spartan.test';
        
        -- 1. Auth Users
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password, 
            email_confirmed_at, created_at, updated_at, 
            raw_app_meta_data, raw_user_meta_data
        ) VALUES (
            '00000000-0000-0000-0000-000000000000', new_user_id, 'authenticated', 'authenticated', 
            fake_email, '$2a$10$dummyHashPasswordForTestsOnlyXXXXX', NOW(), NOW(), NOW(),
            '{"provider": "email"}', 
            jsonb_build_object('nome', 'Aluno Fake ' || i, 'role', 'student')
        );

        -- 2. Public Users Alunos
        INSERT INTO public.users_alunos (
            id,
            id_academia,
            nome,
            email,
            telefone,
            academia,
            cnpj_academia,
            created_at,
            updated_at,
            is_blocked,
            email_verified,
            payment_due_day 
        ) VALUES (
            new_user_id,
            academia_id,
            'Aluno Fake ' || i,
            fake_email,
            '11999999999',
            'Academia Spartan Teste',
            '00000000000100',
            NOW(),
            NOW(),
            false,
            true,
            10 -- Dia de vencimento padrão
        );
        
    END LOOP;
END $$;
