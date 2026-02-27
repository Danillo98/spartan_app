-- ============================================================
-- FIX ZOMBIE POLICIES: EXTIRPAÇÃO DE CNPJ_ACADEMIA
-- v2.6.1 - Spartan App - 2026-02-27
-- ------------------------------------------------------------
-- Este script remove todas as referências residuais à coluna
-- deletada 'cnpj_academia' em tabelas secundárias.
-- Sem isso, o PostgREST falha ao gerar o schema da API.
-- ============================================================

-- 1. LIMPEZA TOTAL EM NOTICES (AVISOS)
-- ============================================================
DROP POLICY IF EXISTS "Todos podem ver avisos da academia" ON public.notices;
DROP POLICY IF EXISTS "Admin pode criar avisos" ON public.notices;
DROP POLICY IF EXISTS "Nutricionista pode criar avisos" ON public.notices;
DROP POLICY IF EXISTS "Personal pode criar avisos" ON public.notices;
DROP POLICY IF EXISTS "Criador pode atualizar aviso" ON public.notices;
DROP POLICY IF EXISTS "Criador pode deletar aviso" ON public.notices;

-- Criar política nova baseada em id_academia (UUID) e JWT
CREATE POLICY "Membros podem ver avisos via JWT" ON public.notices
FOR SELECT USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') OR id_academia = auth.uid() );

CREATE POLICY "Admin/Profissional gerencia avisos" ON public.notices
FOR ALL USING ( 
    id_academia = auth.uid() -- Admin
    OR created_by = auth.uid() -- O próprio criador
);


-- 2. LIMPEZA EM APPOINTMENTS (AGENDAMENTOS)
-- ============================================================
DROP POLICY IF EXISTS "Users can view their academy appointments" ON public.appointments;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Acesso agendamentos via JWT" ON public.appointments
FOR ALL USING ( id_academia::text = (auth.jwt() -> 'user_metadata' ->> 'id_academia') OR id_academia = auth.uid() );


-- 3. REMOÇÃO DE COLUNAS MORTAS (CASO AINDA EXISTAM)
-- ============================================================
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notices' AND column_name='cnpj_academia') THEN
        ALTER TABLE public.notices DROP COLUMN cnpj_academia CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='appointments' AND column_name='cnpj_academia') THEN
        ALTER TABLE public.appointments DROP COLUMN cnpj_academia CASCADE;
    END IF;
END $$;


-- 4. FORÇAR RECARGA DEFINITIVA DA API
-- ============================================================
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload schema';


-- 5. SINCRONIZAR GRANTS
-- ============================================================
GRANT SELECT ON public.notices TO anon, authenticated;
GRANT SELECT ON public.appointments TO anon, authenticated;

SELECT '✅ Zumbis de CNPJ removidos com sucesso! O erro de schema deve estar resolvido.' as status;
