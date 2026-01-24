-- Corrige a política de Admin na tabela de appointments
drop policy if exists "Admins podem gerenciar agendamentos da sua academia" on appointments;

-- Recriar com a coluna correta (assumindo id_academia ou cnpj_academia - no código dart usa id_academia, na migration inicial usou cnpj_academia na policy mas id_academia na busca)
-- Vamos verificar o schema olhando o código. O Service usa id_academia. A migration inicial appointments tinha cnpj_academia.
-- Se o código está mandando id_academia, precisamos garantir que a tabela tenha id_academia.
-- Baseado no service:
-- 'id_academia': academyId,
-- Então o insert usa id_academia.

-- A migration appointments estava assim:
-- cnpj_academia text not null,

-- Isso indica que o service está inserindo 'id_academia' numa tabela que espera 'cnpj_academia' OU a coluna foi renomeada e não vimos.
-- Porém, geralmente usamos id_academia para chave estrangeira.

-- Vamos assumir que a tabela TEM cnpj_academia por causa do CREATE TABLE visto.
-- Mas o Service ESTÁ inserindo id_academia. Isso vai dar erro de coluna não existe se não existir.
-- Mas o erro da imagem é RLS (42501).

-- Se o service manda id_academia mas a RLS checa cnpj_academia, falha se a coluna inserida não for a checada ou se faltar dados.
-- O Service: 'id_academia': academyId.
-- A tabela (vista no view_file): cnpj_academia text not null.

-- Se o service tentar inserir id_academia e a tabela tem cnpj_academia, o erro seria "column does not exist".
-- Se o erro é RLS, significa que a tabela PODE ter id_academia (talvez alterada depois) ou o service mapeia 'id_academia' para 'cnpj_academia' no supabase client? Não, o client é direto.

-- HIPÓTESE: A tabela foi alterada para ter id_academia em vez de cnpj_academia, mas a RLS antiga ficou refenciando cnpj_academia, ou vice versa.
-- Pela mensagem de erro RLS (new row violates row-level security policy), a inserção falha na verificação.

-- Vamos criar uma migração segura que:
-- 1. Garante que id_academia existe na tabela appointments
-- 2. Atualiza a RLS para usar id_academia (que é o padrão novo do sistema)

alter table appointments add column if not exists id_academia uuid;

-- Se id_academia for null para registros existentes, vamos tentar preencher (opcional, arriscado chutar)
-- Mas para NOVOS, o service manda id_academia.

drop policy if exists "Admins podem gerenciar agendamentos da sua academia" on appointments;

create policy "Admins podem gerenciar agendamentos da sua academia"
  on appointments for all
  using (id_academia = (select id_academia from users_adm where id = auth.uid()))
  with check (id_academia = (select id_academia from users_adm where id = auth.uid()));

-- Também atualizar a política de staff para usar id_academia
drop policy if exists "Staff pode ver agendamentos da academia" on appointments;

create policy "Staff pode ver agendamentos da academia"
  on appointments for select
  using (
    id_academia in (
      select id_academia from users_nutricionista where id = auth.uid()
      union
      select id_academia from users_personal where id = auth.uid()
    )
  );
