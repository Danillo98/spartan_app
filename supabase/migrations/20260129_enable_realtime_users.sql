-- HABILITAR REALTIME PARA TABELAS DE USUÁRIOS
-- Isso é necessário para que a funcionalidade de Bloqueio em Tempo Real funcione.
-- Execute este script no Editor SQL do Supabase.

-- 1. Adicionar tabelas à publicação 'supabase_realtime'
-- Usamos 'ADD TABLE' diretamente. Se já estiver lá, ele pode reclamar ou ignorar, 
-- mas geralmente é seguro rodar alter publication add table.
-- Para garantir, vamos tentar adicionar.

DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.users_alunos;
    EXCEPTION WHEN duplicate_object THEN NULL; END;
    
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.users_personal;
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.users_nutricionista;
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.users_adm;
    EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- 2. Verificar se REPLICA IDENTITY está FULL (opcional, mas recomendado para updates completos)
-- ALTER TABLE public.users_alunos REPLICA IDENTITY FULL;
-- ALTER TABLE public.users_personal REPLICA IDENTITY FULL;
-- ALTER TABLE public.users_nutricionista REPLICA IDENTITY FULL;
-- ALTER TABLE public.users_adm REPLICA IDENTITY FULL;

-- 3. Listar tabelas habilitadas para confirmação
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
