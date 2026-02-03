-- Garante que a coluna existe
ALTER TABLE public.users_adm 
ADD COLUMN IF NOT EXISTS plano_mensal text;

-- Remove policies antigas para evitar conflito
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.users_adm;
DROP POLICY IF EXISTS "Enable update for users based on email" ON public.users_adm;
DROP POLICY IF EXISTS "Enable select for users based on email" ON public.users_adm;
DROP POLICY IF EXISTS "Admins can update own data" ON public.users_adm;

-- Criar Policies Permissivas (mas seguras por ID)

-- 1. SELECT: Usuário vê apenas seus dados
CREATE POLICY "Admins can view own data" 
ON public.users_adm FOR SELECT 
USING (auth.uid() = id);

-- 2. INSERT: Trigger handle_new_user faz o insert, mas authenticated pode precisar
CREATE POLICY "Admins can insert own data" 
ON public.users_adm FOR INSERT 
WITH CHECK (auth.uid() = id);

-- 3. UPDATE: Admins podem atualizar TUDO na sua linha
CREATE POLICY "Admins can update own data" 
ON public.users_adm FOR UPDATE 
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Habilitar RLS (se não estiver)
ALTER TABLE public.users_adm ENABLE ROW LEVEL SECURITY;

-- IMPORTANTE: Permissão para a Trigger funcionar (Security Definer já resolve, mas por garantia)
GRANT ALL ON public.users_adm TO postgres, service_role;
GRANT SELECT, INSERT, UPDATE ON public.users_adm TO authenticated;
