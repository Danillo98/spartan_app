-- Migration: Enforce Plan User Limits
-- Description: Bloqueia a criação de novos alunos caso o limite do plano da academia seja atingido.

CREATE OR REPLACE FUNCTION check_plan_user_limit()
RETURNS TRIGGER AS $$
DECLARE
    v_admin_plan TEXT;
    v_current_count INTEGER;
    v_limit INTEGER;
BEGIN
    -- 1. Obter o plano da academia (Admin)
    SELECT plano_mensal INTO v_admin_plan
    FROM users_adm
    WHERE id = NEW.id_academia;

    -- Se não encontrar o admin/plano, permite (ou bloqueia? vamos permitir por enquanto para não quebrar legados)
    IF v_admin_plan IS NULL THEN
        RETURN NEW;
    END IF;

    -- 2. Definir o limite baseado no plano
    -- Normalizar para evitar problemas de case (Prata, PRATA, plata, etc)
    IF ILIKE(v_admin_plan, 'Prata') THEN
        v_limit := 200;
    ELSIF ILIKE(v_admin_plan, 'Ouro') THEN
        v_limit := 500;
    ELSIF ILIKE(v_admin_plan, 'Platina') THEN
        v_limit := 999999; -- Infinito na prática
    ELSE
        -- Plano desconhecido ou Default: vamos assumir Prata (200) ou permitir?
        -- Por segurança, assumimos 200 para evitar abusos em planos inválidos
        v_limit := 200;
    END IF;

    -- 3. Contar quantos alunos essa academia JÁ tem
    SELECT COUNT(*) INTO v_current_count
    FROM users_alunos
    WHERE id_academia = NEW.id_academia;

    -- 4. Verificar se estourou o limite
    -- Nota: v_current_count é antes da inserção atual, então se count = 199, pode inserir (vai virar 200).
    -- Se count = 200, NÃO pode inserir mais.
    IF v_current_count >= v_limit THEN
        RAISE EXCEPTION 'Limite de alunos atingido para o plano %. O limite é % alunos.', v_admin_plan, v_limit;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Remover trigger se já existir para recriar
DROP TRIGGER IF EXISTS trg_check_plan_limit_alunos ON users_alunos;

-- Criar Trigger
CREATE TRIGGER trg_check_plan_limit_alunos
    BEFORE INSERT ON users_alunos
    FOR EACH ROW
    EXECUTE FUNCTION check_plan_user_limit();
