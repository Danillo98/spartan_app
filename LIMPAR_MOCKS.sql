-- CLEANUP SCRIPT (Limpeza)
-- Roda este script após o teste para limpar os 199 alunos falsos

DELETE FROM users_alunos 
WHERE id_academia = 'f954d130-a6ad-4d1b-a61f-c92625f4de18' 
AND email LIKE 'mock_student_%@spartan.test';

SELECT COUNT(*) as "Alunos Restantes" 
FROM users_alunos 
WHERE id_academia = 'f954d130-a6ad-4d1b-a61f-c92625f4de18';
