-- Forçar o recarregamento do cache do esquema do PostgREST
-- Isso resolve erros de "Database error querying schema" após migrações DDL
NOTIFY pgrst, 'reload schema';
