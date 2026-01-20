-- Create Notices table
create table if not exists public.notices (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  cnpj_academia text not null,
  title text not null,
  description text not null,
  start_at timestamp with time zone not null,
  end_at timestamp with time zone not null
);

-- Enable RLS
alter table public.notices enable row level security;

-- Policy: Admin Full Access (CRUD)
create policy "Admins can manage notices"
  on public.notices
  for all
  using (
    cnpj_academia in (
      select cnpj_academia from public.users_adm 
      where id = auth.uid()
    )
  );

-- Policy: Users (Students, Nutris, Professionals) can VIEW active notices
-- Eles precisam ver avisos apenas da academia deles.
-- Como todos os users (users_alunos, users_nutricionista, users_personal) tem cnpj_academia, podemos fazer join ou checar indiretamente.
-- Simplificação: Permitir leitura se tiver o token autenticado e pertencer a tabela de usuários vinculados ao cnpj.

create policy "Users can view notices from their academy"
  on public.notices
  for select
  using (
    -- Verifica se o usuário é aluno dessa academia
    (auth.uid() in (select id from public.users_alunos where cnpj_academia = notices.cnpj_academia))
    OR
    -- Verifica se é nutricionista dessa academia
    (auth.uid() in (select id from public.users_nutricionista where cnpj_academia = notices.cnpj_academia))
    OR
    -- Verifica se é personal dessa academia
    (auth.uid() in (select id from public.users_personal where cnpj_academia = notices.cnpj_academia))
     OR
    -- Tambem permite o admin ver (caso a politica ALL acima falhe ou para select especifico)
    (auth.uid() in (select id from public.users_adm where cnpj_academia = notices.cnpj_academia))
  );
