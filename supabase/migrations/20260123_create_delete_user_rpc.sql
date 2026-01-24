-- Função RPC para DELETAR usuário e TODOS os seus dados relacionados (On Cascade)
-- Exceto transações financeiras (income/expense) que devem permanecer como histórico contábil

create or replace function delete_user_complete(target_user_id uuid)
returns void
language plpgsql
security definer -- Executa como superusuário para ter permissão de deletar do auth.users
as $$
declare
  v_role text;
begin
  -- Tentar descobrir o role antes de deletar para logar melhor no financeiro
  if exists (select 1 from users_alunos where id = target_user_id) then
    v_role := 'Aluno';
  elsif exists (select 1 from users_nutricionista where id = target_user_id) then
    v_role := 'Nutricionista';
  elsif exists (select 1 from users_personal where id = target_user_id) then
    v_role := 'Personal';
  elsif exists (select 1 from users_adm where id = target_user_id) then
    v_role := 'Admin';
  else
    v_role := 'Usuário';
  end if;

  -- 1. DELETAR ou DESVINCULAR dados relacionados
  
  -- DIETAS (Nutritionist)
  -- Se for um nutricionista sendo deletado:
  update diets 
  set nutritionist_id = null 
  where nutritionist_id = target_user_id;

  -- Se for um ALUNO sendo deletado:
  delete from diets where student_id = target_user_id;


  -- TREINOS (Workouts) & Fichas (Training Sheets)
  -- Se for um ALUNO:
  delete from workouts where student_id = target_user_id; -- e seus days/exercises (cascade)
  delete from training_sheets where student_id = target_user_id;

  -- Se for um PERSONAL:
  -- Como treinos são ligados ao aluno, não deletamos os treinos do aluno se o personal sair.
  -- Mas podemos desvincular o author_id se houver, ou manter como histórico.
  -- Por enquanto, nada crítico a fazer no cascade do Personal, pois os dados pertencem ao aluno.


  -- AVALIAÇÕES FÍSICAS
  delete from physical_assessments where student_id = target_user_id;


  -- AGENDAMENTOS (Appointments - Relacionamento N para N com profissionais)
  -- Se for ALUNO:
  delete from appointments where student_id = target_user_id;
  
  -- Se for PROFISSIONAL (Nutri ou Personal):
  -- Precisamos remover este profissional da lista de professionals dos agendamentos
  -- Como professionals é um array ou tabela pivô, depende da implementação.
  -- Supondo tabela pivô 'appointment_professionals' ou array 'professional_ids' na tabela appointments
  
  -- Caso uses tabela appointments com coluna array 'professional_ids':
  -- Remover o ID do array. Se o array ficar vazio, talvez deletar o appointment ou deixar órfão?
  update appointments
  set professional_ids = array_remove(professional_ids, target_user_id::text)
  where target_user_id::text = any(professional_ids);

  
  -- NOTIFICAÇÕES
  delete from notifications where user_id = target_user_id;


  -- 2. TRATAMENTO FINANCEIRO (Preservar Histórico)
  update financial_transactions
  set 
    related_user_id = null,
    description = description || ' (' || v_role || ' Deletado)' 
  where related_user_id = target_user_id;

  -- 3. DELETAR PERFIL NAS TABELAS
  delete from users_alunos where id = target_user_id;
  delete from users_nutricionista where id = target_user_id;
  delete from users_personal where id = target_user_id;
  delete from users_adm where id = target_user_id;

  -- 4. DELETAR CONTA DE AUTENTICAÇÃO
  delete from auth.users where id = target_user_id;

exception
  when others then
    raise exception 'Erro ao deletar usuário: %', sqlerrm;
end;
$$;
