-- Remove unused column 'cnpj' from users_adm table
-- The correct column being used is 'cnpj_academia'

alter table public.users_adm drop column if exists cnpj;
