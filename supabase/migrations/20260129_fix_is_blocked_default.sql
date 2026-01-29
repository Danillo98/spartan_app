-- GARANTIR QUE NOVOS USUÁRIOS SEMPRE TENHAM is_blocked = FALSE
-- Trigger para garantir que o campo is_blocked seja sempre FALSE ao criar um novo usuário

-- Função para garantir is_blocked = FALSE
CREATE OR REPLACE FUNCTION ensure_is_blocked_false()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Se is_blocked for NULL ou não definido, definir como FALSE
    IF NEW.is_blocked IS NULL THEN
        NEW.is_blocked := FALSE;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Trigger para users_alunos
DROP TRIGGER IF EXISTS ensure_is_blocked_false_alunos ON users_alunos;
CREATE TRIGGER ensure_is_blocked_false_alunos
    BEFORE INSERT ON users_alunos
    FOR EACH ROW
    EXECUTE FUNCTION ensure_is_blocked_false();

-- Trigger para users_nutricionista
DROP TRIGGER IF EXISTS ensure_is_blocked_false_nutri ON users_nutricionista;
CREATE TRIGGER ensure_is_blocked_false_nutri
    BEFORE INSERT ON users_nutricionista
    FOR EACH ROW
    EXECUTE FUNCTION ensure_is_blocked_false();

-- Trigger para users_personal
DROP TRIGGER IF EXISTS ensure_is_blocked_false_personal ON users_personal;
CREATE TRIGGER ensure_is_blocked_false_personal
    BEFORE INSERT ON users_personal
    FOR EACH ROW
    EXECUTE FUNCTION ensure_is_blocked_false();

-- Trigger para users_adm
DROP TRIGGER IF EXISTS ensure_is_blocked_false_adm ON users_adm;
CREATE TRIGGER ensure_is_blocked_false_adm
    BEFORE INSERT ON users_adm
    FOR EACH ROW
    EXECUTE FUNCTION ensure_is_blocked_false();

-- Atualizar todos os usuários existentes que possam ter is_blocked = NULL
UPDATE users_alunos SET is_blocked = FALSE WHERE is_blocked IS NULL;
UPDATE users_nutricionista SET is_blocked = FALSE WHERE is_blocked IS NULL;
UPDATE users_personal SET is_blocked = FALSE WHERE is_blocked IS NULL;
UPDATE users_adm SET is_blocked = FALSE WHERE is_blocked IS NULL;

COMMENT ON FUNCTION ensure_is_blocked_false() IS 
'Garante que o campo is_blocked seja sempre FALSE ao criar um novo usuário, evitando bloqueios acidentais.';
