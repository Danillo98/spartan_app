-- DIAGNOSTICO DE AGENDAMENTOS E PROFISSIONAIS
-- Execute para verificar se os agendamentos tem os IDs dos profissionais salvos corretamente

SELECT 
    a.id,
    a.created_at,
    a.scheduled_at,
    a.professional_ids, -- <--- ESTA COLUNA QUE IMPORTA
    COALESCE(u.nome, a.visitor_name) as aluno_nome,
    a.status
FROM 
    public.appointments a
LEFT JOIN 
    public.users_alunos u ON a.student_id = u.id
ORDER BY 
    a.created_at DESC
LIMIT 10;

-- Se 'professional_ids' estiver NULL ou [], o agendamento não aparecerá para ninguém.
