-- Force update to version 1.0.3
UPDATE public.app_versao 
SET versao_atual = '1.0.3', 
    updated_at = now() 
WHERE id = 1;
