-- Force update to version 1.0.4
-- This table is checked by the app on startup.

UPDATE public.app_versao
SET versao_atual = '1.0.4'
WHERE id = 1;
