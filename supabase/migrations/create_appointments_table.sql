-- Criação da tabela de Agendamentos (Avaliações Físicas)
create table if not exists appointments (
  id uuid default gen_random_uuid() primary key,
  cnpj_academia text not null,
  
  -- Dados do Agendado (Aluno ou Visitante)
  student_id uuid references users_alunos(id), -- Null se for visitante
  visitor_name text, -- Preenchido se student_id for null
  visitor_phone text, -- Preenchido se student_id for null
  
  -- Profissionais responsáveis (Array de IDs)
  -- Pode conter IDs de users_nutricionista e/ou users_personal
  professional_ids jsonb not null default '[]'::jsonb,
  
  -- Data e Hora
  scheduled_at timestamp with time zone not null,
  
  -- Status
  status text not null default 'scheduled' check (status in ('scheduled', 'confirmed', 'completed', 'cancelled', 'no_show')),
  
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Políticas de Segurança (RLS)
alter table appointments enable row level security;

-- Admin pode fazer tudo em sua academia
create policy "Admins podem gerenciar agendamentos da sua academia"
  on appointments for all
  using (cnpj_academia = (select cnpj_academia from users_adm where id = auth.uid()))
  with check (cnpj_academia = (select cnpj_academia from users_adm where id = auth.uid()));

-- Nutricionistas podem ver agendamentos onde estão incluídos
-- (Lógica simplificada: ver todos da academia por enquanto para facilitar agenda global)
create policy "Staff pode ver agendamentos da academia"
  on appointments for select
  using (
    cnpj_academia in (
      select cnpj_academia from users_nutricionista where id = auth.uid()
      union
      select cnpj_academia from users_personal where id = auth.uid()
    )
  );
