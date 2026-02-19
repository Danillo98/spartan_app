-- Add subscription tracking columns to users_adm if they don't exist

DO $$
BEGIN
    -- assinatura_status
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_adm' AND column_name = 'assinatura_status') THEN
        ALTER TABLE users_adm ADD COLUMN assinatura_status text DEFAULT 'active';
    END IF;

    -- assinatura_iniciada
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_adm' AND column_name = 'assinatura_iniciada') THEN
        ALTER TABLE users_adm ADD COLUMN assinatura_iniciada timestamp;
    END IF;

    -- assinatura_expirada
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_adm' AND column_name = 'assinatura_expirada') THEN
        ALTER TABLE users_adm ADD COLUMN assinatura_expirada timestamp;
    END IF;

    -- assinatura_tolerancia
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_adm' AND column_name = 'assinatura_tolerancia') THEN
        ALTER TABLE users_adm ADD COLUMN assinatura_tolerancia timestamp;
    END IF;

    -- assinatura_deletada
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_adm' AND column_name = 'assinatura_deletada') THEN
        ALTER TABLE users_adm ADD COLUMN assinatura_deletada timestamp;
    END IF;

    -- stripe_customer_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users_adm' AND column_name = 'stripe_customer_id') THEN
        ALTER TABLE users_adm ADD COLUMN stripe_customer_id text;
    END IF;
END $$;
