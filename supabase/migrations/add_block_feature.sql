-- Adicionar coluna is_blocked nas tabelas de usuários
ALTER TABLE users_alunos ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE;
ALTER TABLE users_nutricionista ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE;
ALTER TABLE users_personal ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE;
ALTER TABLE users_adm ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE;

-- Opcional: Atualizar usuários existentes para false
UPDATE users_alunos SET is_blocked = FALSE WHERE is_blocked IS NULL;
UPDATE users_nutricionista SET is_blocked = FALSE WHERE is_blocked IS NULL;
UPDATE users_personal SET is_blocked = FALSE WHERE is_blocked IS NULL;
UPDATE users_adm SET is_blocked = FALSE WHERE is_blocked IS NULL;
