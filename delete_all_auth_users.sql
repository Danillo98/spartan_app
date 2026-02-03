-- ☢️ PERIGO: ESTE SCRIPT APAGA TODOS OS USUÁRIOS DE AUTENTICAÇÃO ☢️
-- Isso impedirá que qualquer pessoa faça login e, se suas tabelas 
-- estiverem configuradas com 'ON DELETE CASCADE', apagará também 
-- todos os dados de perfil, treinos, dietas, etc.

-- Dica: Se quiser apagar apenas usuarios de teste, use WHERE email LIKE '%teste%' ou similar.

DELETE FROM auth.users;

-- Se o comando acima falhar por violação de Foreign Key, 
-- significa que o CASCADE não está automático. Nesse caso, use:
-- TRUNCATE auth.users CASCADE;
