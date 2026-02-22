-- ========================================================
-- CRIAÇÃO DO STATUS FINANCEIRO MASTER PARA ALUNOS
-- Facilitar sincronização com a catraca e aliviar o motor
-- ========================================================

-- 1. Adicionar coluna na tabela users_alunos
ALTER TABLE public.users_alunos 
ADD COLUMN IF NOT EXISTS status_financeiro TEXT DEFAULT 'pending';

-- 2. Função para calcular o status (Lógica Ledger sincronizada com o Flutter)
CREATE OR REPLACE FUNCTION public.fn_calculate_student_status(p_student_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_created_at TIMESTAMP;
    v_payment_due INT;
    v_paid_count INT;
    v_months_since_entry INT;
    v_now TIMESTAMP := NOW();
    v_status TEXT := 'pending';
BEGIN
    -- Obter dados do aluno
    SELECT created_at, COALESCE(payment_due, 10)
    INTO v_created_at, v_payment_due
    FROM public.users_alunos
    WHERE id = p_student_id;

    IF NOT FOUND THEN RETURN 'unknown'; END IF;

    -- Contar pagamentos realizados
    SELECT COUNT(*)
    INTO v_paid_count
    FROM public.financial_transactions
    WHERE related_user_id = p_student_id
      AND type = 'income'
      AND related_user_role = 'student';

    -- Calcular meses desde a entrada (Incluindo o mês atual)
    v_months_since_entry := (EXTRACT(YEAR FROM v_now) - EXTRACT(YEAR FROM v_created_at)) * 12 
                          + (EXTRACT(MONTH FROM v_now) - EXTRACT(MONTH FROM v_created_at)) + 1;

    IF v_months_since_entry < 1 THEN v_months_since_entry := 1; END IF;

    -- Lógica de Status
    IF v_paid_count >= v_months_since_entry THEN
        v_status := 'paid';
    ELSIF v_paid_count < v_months_since_entry - 1 THEN
        -- Deve meses anteriores
        v_status := 'overdue';
    ELSE
        -- Deve apenas o mês atual
        IF EXTRACT(DAY FROM v_now) > v_payment_due THEN
            v_status := 'overdue';
        ELSE
            v_status := 'pending';
        END IF;
    END IF;

    RETURN v_status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Função para o Trigger
CREATE OR REPLACE FUNCTION public.fn_trigger_refresh_student_status()
RETURNS TRIGGER AS $$
DECLARE
    v_student_id UUID;
    v_new_status TEXT;
BEGIN
    -- Identificar o aluno afetado
    IF TG_TABLE_NAME = 'financial_transactions' THEN
        v_student_id := COALESCE(NEW.related_user_id, OLD.related_user_id);
        -- Só interessa se for aluno
        IF COALESCE(NEW.related_user_role, OLD.related_user_role) != 'student' THEN
            RETURN NULL;
        END IF;
    ELSE
        v_student_id := NEW.id;
    END IF;

    IF v_student_id IS NOT NULL THEN
        -- Calcular novo status
        v_new_status := public.fn_calculate_student_status(v_student_id);
        
        -- Atualizar na tabela de alunos
        UPDATE public.users_alunos 
        SET status_financeiro = v_new_status
        WHERE id = v_student_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Criar Triggers
DROP TRIGGER IF EXISTS tr_refresh_status_on_transaction ON public.financial_transactions;
CREATE TRIGGER tr_refresh_status_on_transaction
AFTER INSERT OR UPDATE OR DELETE ON public.financial_transactions
FOR EACH ROW EXECUTE FUNCTION public.fn_trigger_refresh_student_status();

DROP TRIGGER IF EXISTS tr_refresh_status_on_student_change ON public.users_alunos;
CREATE TRIGGER tr_refresh_status_on_student_change
AFTER UPDATE OF payment_due, created_at ON public.users_alunos
FOR EACH ROW EXECUTE FUNCTION public.fn_trigger_refresh_student_status();

-- 5. Sincronização Inicial (Rodar para todos os alunos atuais)
UPDATE public.users_alunos 
SET status_financeiro = public.fn_calculate_student_status(id);

-- 6. Garantir que a coluna está no Realtime
-- Nota: Isso precisa de permissão de admin no canal realtime do Supabase.
-- Como não temos acesso direto ao console, assumimos que a tabela já está no realtime 'public'.
