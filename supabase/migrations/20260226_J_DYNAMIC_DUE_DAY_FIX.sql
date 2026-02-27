-- ============================================
-- ATUALIZAÇÃO SÍNCRONA DE NEXT_PAYMENT_DUE E STATUS 
-- AO EDITAR DIA DE VENCIMENTO DO ALUNO (V2.6.0)
-- ============================================

-- Atualiza next_payment_due imediatamente se o dia de vencimento mudar
CREATE OR REPLACE FUNCTION trg_sync_payment_due_day()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payment_due_day IS DISTINCT FROM OLD.payment_due_day THEN
        NEW.next_payment_due = make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT, NEW.payment_due_day);
        IF NEW.next_payment_due < CURRENT_DATE THEN 
            NEW.next_payment_due := NEW.next_payment_due + INTERVAL '1 month'; 
        END IF;

        -- Já recalcula o status para evitar uma segunda query
        NEW.status_financeiro = public.fn_calculate_student_status(NEW.id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_sync_payment_due_day ON public.users_alunos;
CREATE TRIGGER trigger_sync_payment_due_day
BEFORE UPDATE OF payment_due_day ON public.users_alunos
FOR EACH ROW
EXECUTE FUNCTION trg_sync_payment_due_day();

SELECT '✅ Trigger de Vencimento Dinâmico criado com sucesso' as status;
