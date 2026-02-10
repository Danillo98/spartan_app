-- ============================================
-- AUTOMAÇÃO DE LIMPEZA DE CONTAS EXPIRADAS (CORRIGIDO)
-- ============================================

-- 1. Habilitar extensão pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Criar a função que busca e deleta contas vencidas
CREATE OR REPLACE FUNCTION delete_expired_accounts_task()
RETURNS void AS $$
DECLARE
    r RECORD;
    deleted_count INTEGER := 0;
BEGIN
    FOR r IN 
        SELECT id, email, assinatura_deletada 
        FROM public.users_adm 
        WHERE assinatura_deletada IS NOT NULL 
          AND assinatura_deletada < NOW() 
    LOOP
        RAISE NOTICE '🗑️ Auto-cleaning account: % (Exp: %)', r.email, r.assinatura_deletada;
        PERFORM delete_academia_by_id_v3(r.id);
        deleted_count := deleted_count + 1;
    END LOOP;

    IF deleted_count > 0 THEN
        RAISE NOTICE '✅ Auto-cleanup finished. Deleted % accounts.', deleted_count;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Agendar a tarefa (Maneira segura)
-- Removemos direto da tabela para evitar erro se não existir
DELETE FROM cron.job WHERE jobname = 'spartan-auto-cleanup';

-- Agora agendamos
SELECT cron.schedule(
    'spartan-auto-cleanup', -- Nome da tarefa
    '0 3 * * *',            -- Todo dia as 03:00 UTC
    'SELECT delete_expired_accounts_task()'
);

-- Conferir agendamento
SELECT * FROM cron.job;
