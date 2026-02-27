-- ============================================================
-- FIX DEFINITIVO: Corrige triggers conflitantes em users_alunos
-- Resolve "record new has no field related_user_id"
-- ============================================================

-- 1. Dropa TODOS os triggers problemáticos em users_alunos
DROP TRIGGER IF EXISTS trigger_sync_payment_due_day ON public.users_alunos;
DROP TRIGGER IF EXISTS tr_refresh_status_on_student_change ON public.users_alunos;
-- Dropa funções antigas que podem ter referências erradas
DROP FUNCTION IF EXISTS public.trg_sync_payment_due_day() CASCADE;

-- 2. Corrige fn_calculate_student_status: coluna era "payment_due", correta é "payment_due_day"
CREATE OR REPLACE FUNCTION public.fn_calculate_student_status(p_student_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_created_at        TIMESTAMP;
    v_payment_due_day   INT;
    v_paid_count        INT;
    v_months_since      INT;
    v_now               TIMESTAMP := NOW();
    v_due_this_month    DATE;
    v_status            TEXT := 'pending';
BEGIN
    -- Obter dados do aluno (corrigido: payment_due_day)
    SELECT created_at, COALESCE(payment_due_day, 10)
    INTO v_created_at, v_payment_due_day
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

    -- Meses desde a entrada (inclui mês atual)
    v_months_since := (EXTRACT(YEAR FROM v_now) - EXTRACT(YEAR FROM v_created_at)) * 12
                    + (EXTRACT(MONTH FROM v_now) - EXTRACT(MONTH FROM v_created_at)) + 1;

    IF v_months_since < 1 THEN v_months_since := 1; END IF;

    -- Vencimento do mês atual
    BEGIN
        v_due_this_month := make_date(
            EXTRACT(YEAR FROM v_now)::INT,
            EXTRACT(MONTH FROM v_now)::INT,
            v_payment_due_day
        );
    EXCEPTION WHEN OTHERS THEN
        -- Dia inválido para o mês (ex: 31 em fevereiro)
        v_due_this_month := (date_trunc('month', v_now) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
    END;

    -- Lógica de Status
    IF v_paid_count >= v_months_since THEN
        v_status := 'paid';
    ELSIF v_paid_count < v_months_since - 1 THEN
        v_status := 'overdue';
    ELSE
        IF CURRENT_DATE > v_due_this_month THEN
            v_status := 'overdue';
        ELSE
            v_status := 'pending';
        END IF;
    END IF;

    RETURN v_status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Corrige fn_trigger_refresh_student_status: compatível com ambas as tabelas
CREATE OR REPLACE FUNCTION public.fn_trigger_refresh_student_status()
RETURNS TRIGGER AS $$
DECLARE
    v_student_id UUID;
    v_new_status TEXT;
BEGIN
    -- Apenas para financial_transactions
    IF TG_TABLE_NAME = 'financial_transactions' THEN
        v_student_id := COALESCE(NEW.related_user_id, OLD.related_user_id);
        IF COALESCE(NEW.related_user_role, OLD.related_user_role) != 'student' THEN
            RETURN NULL;
        END IF;
    ELSE
        -- Não deve ser usado em users_alunos (veja abaixo)
        RETURN NULL;
    END IF;

    IF v_student_id IS NOT NULL THEN
        v_new_status := public.fn_calculate_student_status(v_student_id);
        UPDATE public.users_alunos
        SET status_financeiro = v_new_status
        WHERE id = v_student_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Recriar apenas o trigger em financial_transactions (sem trigger em users_alunos)
DROP TRIGGER IF EXISTS tr_refresh_status_on_transaction ON public.financial_transactions;
CREATE TRIGGER tr_refresh_status_on_transaction
AFTER INSERT OR UPDATE OR DELETE ON public.financial_transactions
FOR EACH ROW EXECUTE FUNCTION public.fn_trigger_refresh_student_status();

-- 5. Sincronização inicial com a função corrigida
UPDATE public.users_alunos
SET status_financeiro = public.fn_calculate_student_status(id);

NOTIFY pgrst, 'reload schema';

SELECT '✅ Triggers corrigidos e status recalculado para todos os alunos!' as status;
