-- ============================================================
-- RPC SECURITY DEFINER: admin_update_user_data
-- Bypassa RLS para permitir que o admin edite dados de qualquer usuário da academia
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_update_user_data(
    p_admin_id     UUID,     -- ID do admin logado (auth.uid())
    p_user_id      UUID,     -- ID do usuário a editar
    p_role         TEXT,     -- 'student', 'nutritionist', 'trainer', 'admin'
    p_name         TEXT DEFAULT NULL,
    p_email        TEXT DEFAULT NULL,
    p_phone        TEXT DEFAULT NULL,
    p_birth_date   DATE DEFAULT NULL,
    p_due_day      INT  DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_table        TEXT;
    v_id_academia  UUID;
    v_user_academia UUID;
BEGIN
    -- 1. Descobre a academia do admin
    SELECT id INTO v_id_academia FROM public.users_adm WHERE id = p_admin_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Admin não encontrado');
    END IF;

    -- 2. Determina a tabela correta
    v_table := CASE p_role
        WHEN 'admin'         THEN 'users_adm'
        WHEN 'nutritionist'  THEN 'users_nutricionista'
        WHEN 'trainer'       THEN 'users_personal'
        ELSE                      'users_alunos'
    END;

    -- 3. Validação: usuário pertence à mesma academia
    IF p_role = 'student' THEN
        SELECT id_academia INTO v_user_academia FROM public.users_alunos WHERE id = p_user_id;
    ELSIF p_role = 'nutritionist' THEN
        SELECT id_academia INTO v_user_academia FROM public.users_nutricionista WHERE id = p_user_id;
    ELSIF p_role = 'trainer' THEN
        SELECT id_academia INTO v_user_academia FROM public.users_personal WHERE id = p_user_id;
    ELSE
        v_user_academia := p_user_id; -- Admins: id = id_academia
    END IF;

    IF v_user_academia IS DISTINCT FROM v_id_academia AND p_role != 'admin' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Usuário não pertence à sua academia');
    END IF;

    -- 4. Monta updates de forma dinâmica via conditionais
    -- Usamos UPDATE com CASE para não precisar de SQL dinâmico

    IF p_role = 'student' THEN
        UPDATE public.users_alunos SET
            nome           = COALESCE(p_name, nome),
            email          = COALESCE(p_email, email),
            telefone       = COALESCE(NULLIF(p_phone, ''), telefone),
            data_nascimento= COALESCE(p_birth_date, data_nascimento),
            payment_due_day= COALESCE(p_due_day, payment_due_day),
            next_payment_due = CASE
                WHEN p_due_day IS NOT NULL THEN
                    CASE WHEN make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT, p_due_day) < CURRENT_DATE
                         THEN make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT, p_due_day) + INTERVAL '1 month'
                         ELSE make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT, p_due_day)
                    END
                ELSE next_payment_due
            END,
            status_financeiro = CASE
                WHEN p_due_day IS NOT NULL THEN public.fn_calculate_student_status(p_user_id)
                ELSE status_financeiro
            END,
            updated_at = NOW()
        WHERE id = p_user_id;

    ELSIF p_role = 'nutritionist' THEN
        UPDATE public.users_nutricionista SET
            nome     = COALESCE(p_name, nome),
            email    = COALESCE(p_email, email),
            telefone = COALESCE(NULLIF(p_phone, ''), telefone),
            data_nascimento = COALESCE(p_birth_date, data_nascimento),
            updated_at = NOW()
        WHERE id = p_user_id;

    ELSIF p_role = 'trainer' THEN
        UPDATE public.users_personal SET
            nome     = COALESCE(p_name, nome),
            email    = COALESCE(p_email, email),
            telefone = COALESCE(NULLIF(p_phone, ''), telefone),
            data_nascimento = COALESCE(p_birth_date, data_nascimento),
            updated_at = NOW()
        WHERE id = p_user_id;

    ELSE -- admin
        UPDATE public.users_adm SET
            nome     = COALESCE(p_name, nome),
            email    = COALESCE(p_email, email),
            telefone = COALESCE(NULLIF(p_phone, ''), telefone),
            updated_at = NOW()
        WHERE id = p_user_id;
    END IF;

    -- 5. Atualiza email em auth.users se necessário
    IF p_email IS NOT NULL THEN
        UPDATE auth.users SET email = p_email, updated_at = NOW() WHERE id = p_user_id;
    END IF;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Usuário atualizado com sucesso');

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Erro: ' || SQLERRM);
END;
$$;

-- Garante que apenas usuários autenticados possam chamar (mas a lógica interna valida que é admin)
GRANT EXECUTE ON FUNCTION public.admin_update_user_data TO authenticated;

NOTIFY pgrst, 'reload schema';

SELECT '✅ RPC admin_update_user_data criada com sucesso!' as status;
