-- Add created_by column to track who created the notice
alter table public.notices 
add column if not exists created_by uuid references auth.users(id);

-- Update RLS Policies

-- 1. DROP existing policies to start fresh
drop policy if exists "Admins can manage notices" on public.notices;
drop policy if exists "Users can view notices from their academy" on public.notices;

-- 2. CREATE READ Policy (All users from the academy can see active notices, creators can see all their notices)
create policy "Read Access"
  on public.notices
  for select
  using (
    -- Admin sees everything from their academy
    (auth.uid() in (select id from public.users_adm where cnpj_academia = notices.cnpj_academia))
    OR
    -- Creator sees their own notices
    (created_by = auth.uid())
    OR
    -- Others see active notices targeting them or global
    (
        cnpj_academia in (
             select cnpj_academia from public.users_alunos where id = auth.uid()
             union
             select cnpj_academia from public.users_nutricionista where id = auth.uid()
             union
             select cnpj_academia from public.users_personal where id = auth.uid()
        )
        AND
        (target_student_id is null OR target_student_id = auth.uid())
    )
  );

-- 3. CREATE WRITE Policy (Admins, Nutritionists, Trainers can create/edit/delete)
create policy "Write Access"
  on public.notices
  for all -- Covers insert, update, delete
  using (
      -- Must be Admin, Nutri or Trainer
      (
          auth.uid() in (select id from public.users_adm where cnpj_academia = notices.cnpj_academia)
          OR
          auth.uid() in (select id from public.users_nutricionista where cnpj_academia = notices.cnpj_academia)
          OR
          auth.uid() in (select id from public.users_personal where cnpj_academia = notices.cnpj_academia)
      )
  )
  with check (
      -- Same check for inserts/updates
      (
          auth.uid() in (select id from public.users_adm where cnpj_academia = notices.cnpj_academia)
          OR
          auth.uid() in (select id from public.users_nutricionista where cnpj_academia = notices.cnpj_academia)
          OR
          auth.uid() in (select id from public.users_personal where cnpj_academia = notices.cnpj_academia)
      )
  );
