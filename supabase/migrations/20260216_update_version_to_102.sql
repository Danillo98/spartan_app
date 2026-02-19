-- Atualiza a versão do app para 1.0.2 para forçar o reload nos clientes
-- Isso garante que todos os usuários passem a usar as chaves de produção configuradas

-- Verifica se a tabela existe (já deve existir pela migração anterior)
-- Insere ou Atualiza a única linha permitida
INSERT INTO public.app_versao (id, versao_atual, updated_at)
VALUES (1, '1.0.2', now())
ON CONFLICT (id) DO UPDATE
SET versao_atual = '1.0.2',
    updated_at = now();
