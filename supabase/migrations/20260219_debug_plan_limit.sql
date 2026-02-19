-- Script de Debug e Correção para Limites do Plano
-- 1. Força o plano Diamante para a academia específica (remove espaços extras)
-- 2. Atualiza a trigger para mostrar detalhes exatos do erro se falhar

-- 1. Forçar Plano Diamante
UPDATE public.users_adm 
SET plano_mensal = 'Diamante' 
WHERE id = '838604d9-bc4d-4259-b283-eede44f4f892';

-- 2. Atualizar Função com Debug Detalhado
CREATE OR REPLACE FUNCTION public.check_plan_user_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_admin_plan text;
    v_count int;
    v_limit int;
BEGIN
    -- Buscar plano
    SELECT plano_mensal INTO v_admin_plan FROM public.users_adm WHERE id = NEW.id_academia;
    
    -- Normalizar (remover espaços que podem causar erro na comparação)
    v_admin_plan := TRIM(COALESCE(v_admin_plan, ''));

    -- Definir limites
    IF v_admin_plan ILIKE 'Prata' THEN v_limit := 200;
    ELSIF v_admin_plan ILIKE 'Ouro' THEN v_limit := 500;
    ELSIF v_admin_plan ILIKE 'Platina' THEN v_limit := 800;
    ELSIF v_admin_plan ILIKE 'Diamante' THEN v_limit := 999999; -- Infinito na prática
    ELSE 
        v_limit := 200; -- Default seguro
    END IF;

    -- Contar alunos atuais (incluindo o que está sendo inserido se trigger for AFTER, mas aqui é BEFORE/AFTER INSERT, melhor contar tudo da academia)
    SELECT count(*) INTO v_count FROM public.users_alunos WHERE id_academia = NEW.id_academia;

    -- Verificar
    IF v_count >= v_limit THEN
        RAISE EXCEPTION 'ERRO DE LIMITE DETALHADO: Plano Atual="%" | Limite=% | Alunos Atuais=% | ID Academia=%', v_admin_plan, v_limit, v_count, NEW.id_academia;
    END IF;

    RETURN NEW;
END;
$function$;
