-- Add columns for targeting specific students and labeling the author
alter table public.notices 
add column if not exists target_student_id uuid references public.users_alunos(id),
add column if not exists author_label text default 'Gestão da Academia';

-- Update RLS Policy for Students to see their specific notices + general notices
drop policy if exists "Users can view notices from their academy" on public.notices;

create policy "Users can view notices from their academy"
  on public.notices
  for select
  using (
    -- Pertence à mesma academia
    (
        -- Verifica academia via usuários (simplificado para performance)
        cnpj_academia in (
             select cnpj_academia from public.users_alunos where id = auth.uid()
        )
        AND
        -- E (É um aviso geral OU é direcionado especificamente para este aluno)
        (target_student_id is null OR target_student_id = auth.uid())
    )
    OR
    -- Mantém a visualização para Nutris/Personais/Admins daquela academia verem tudo (opcional, ou limitamos)
    (auth.uid() in (select id from public.users_adm where cnpj_academia = notices.cnpj_academia))
    OR
    (auth.uid() in (select id from public.users_nutricionista where cnpj_academia = notices.cnpj_academia))
    OR
    (auth.uid() in (select id from public.users_personal where cnpj_academia = notices.cnpj_academia))
  );
