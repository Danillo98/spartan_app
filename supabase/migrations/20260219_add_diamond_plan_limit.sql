-- Migration: Add Diamond Plan and Update Platinum Limit
-- Description: Adiciona limite para o plano Platina (800) e libera Diamante (Infinito).

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
    IF v_admin_plan ILIKE 'Prata' THEN
        v_limit := 200;
    ELSIF v_admin_plan ILIKE 'Ouro' THEN
        v_limit := 500;
    ELSIF v_admin_plan ILIKE 'Platina' THEN
        v_limit := 800; -- NOVO LIMITE! Antes era infinito
    ELSIF v_admin_plan ILIKE 'Diamante' THEN
        v_limit := 999999; -- NOVO PLANO INFINITO
    ELSE
        -- Plano desconhecido ou Default: vamos assumir Prata (200) para evitar abusos
        v_limit := 200;
    END IF;

    -- 3. Contar quantos alunos essa academia JÁ tem
    SELECT COUNT(*) INTO v_current_count
    FROM users_alunos
    WHERE id_academia = NEW.id_academia;

    -- 4. Verificar se estourou o limite
    -- Nota: v_current_count é antes da inserção atual
    IF v_current_count >= v_limit THEN
        RAISE EXCEPTION 'Limite de alunos atingido para o plano %. O limite é % alunos.', v_admin_plan, v_limit;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
