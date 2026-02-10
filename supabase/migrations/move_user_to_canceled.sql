-- ============================================
-- FUNÇÃO: Mover Usuário para Histórico de Cancelados (SEM DELETAR)
-- ============================================

CREATE OR REPLACE FUNCTION copy_user_to_canceled_v1(target_user_id UUID, motivo TEXT DEFAULT NULL)
RETURNS BOOLEAN AS $$
DECLARE
    source_user RECORD;
BEGIN
    -- 1. Buscar usuário original
    SELECT * INTO source_user 
    FROM public.users_adm 
    WHERE id = target_user_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Usuário % não encontrado em users_adm', target_user_id;
        RETURN FALSE;
    END IF;

    -- 2. Inserir na tabela de cancelados (Upsert para evitar duplicação)
    INSERT INTO public.users_canceled (
        original_id,
        nome,
        email,
        telefone,
        cnpj_academia,
        cpf,
        academia,
        endereco,
        plano_mensal,
        assinatura_iniciada,
        assinatura_expirada,
        stripe_customer_id,
        motivo_cancelamento,
        cancelado_em
    ) VALUES (
        source_user.id,
        source_user.nome,
        source_user.email,
        source_user.telefone,
        source_user.cnpj_academia,
        source_user.cpf,
        source_user.academia,
        source_user.endereco,
        source_user.plano_mensal,
        source_user.assinatura_iniciada,
        source_user.assinatura_expirada,
        source_user.stripe_customer_id,
        motivo,
        NOW()
    )
    ON CONFLICT (original_id) DO UPDATE SET
        cancelado_em = NOW(), -- Atualiza data se cancelar novamente
        motivo_cancelamento = motivo,
        assinatura_expirada = EXCLUDED.assinatura_expirada;

    -- 3. Marcar usuário original como suspenso (NÃO DELETA MAIS!)
    UPDATE public.users_adm
    SET 
        assinatura_status = 'suspended',
        is_blocked = true,
        updated_at = NOW()
    WHERE id = target_user_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
