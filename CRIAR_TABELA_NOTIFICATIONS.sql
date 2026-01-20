-- ============================================
-- TABELA DE NOTIFICAÇÕES
-- Execute este script no Supabase SQL Editor
-- ============================================

-- Criar tabela de notificações
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    sender_name TEXT,
    type TEXT DEFAULT 'alert', -- alert, reminder, system
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);

-- Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);

-- Habilitar RLS (Row Level Security)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Política: Usuários podem ver apenas suas próprias notificações
CREATE POLICY "Users can view own notifications"
    ON public.notifications
    FOR SELECT
    USING (auth.uid() = user_id);

-- Política: Personals e Nutricionistas podem inserir notificações
CREATE POLICY "Trainers and nutritionists can insert notifications"
    ON public.notifications
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid()
            AND role IN ('trainer', 'nutritionist')
        )
    );

-- Política: Usuários podem atualizar suas próprias notificações (marcar como lida)
CREATE POLICY "Users can update own notifications"
    ON public.notifications
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Política: Usuários podem deletar suas próprias notificações
CREATE POLICY "Users can delete own notifications"
    ON public.notifications
    FOR DELETE
    USING (auth.uid() = user_id);

-- Comentários
COMMENT ON TABLE public.notifications IS 'Tabela de notificações para alunos';
COMMENT ON COLUMN public.notifications.type IS 'Tipo de notificação: alert (alerta do personal/nutricionista), reminder (lembrete), system (sistema)';
COMMENT ON COLUMN public.notifications.sender_name IS 'Nome de quem enviou a notificação (personal ou nutricionista)';
