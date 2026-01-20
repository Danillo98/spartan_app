# Ponto de Restauração: RICO
**Data:** 18/01/2026

## Estado Atual do Projeto

### Sistema de Avisos (Notices)
- **Banco de Dados:**
    - Tabela `notices` atualizada com `target_student_id`, `author_label` e `created_by`.
    - Políticas RLS (Security) configuradas para permitir que Admin, Nutricionista e Personal criem e gerenciem seus avisos, e que Alunos visualizem apenas o permitido.
- **Backend (Services):**
    - `NoticeService`:
        - `createNotice`: Suporta autoria e direcionamento.
        - `getActiveNotices`: Retorna lista de avisos relevantes para o aluno.
        - `getMyNotices`: Retorna avisos criados pelo profissional logado.
        - `deleteNotice`: Permite exclusão.

### Interface do Usuário (UI)
- **Área do Aluno:**
    - `BulletinBoardCard`:
        - Exibe múltiplos avisos em lista.
        - **Cores Dinâmicas:**
            - Admin: Preto
            - Nutricionista: Verde
            - Personal: Vermelho
        - Exibe autor e data.
- **Área do Nutricionista e Personal Trainer:**
    - Telas `MyStudents...`:
        - Convertidas para **Abas (Tabs)**:
            1. "Meus Alunos": Lista para seleção e envio.
            2. "Avisos Enviados": Lista de histórico com opção de exclusão.
        - Botão "Enviar Aviso" abre formulário completo (Título, Descrição, Datas).

### Ações Pendentes
- Testar envio de avisos por todos os perfis.
- Verificar se as cores estão aparecendo corretamente no app do aluno.

---
*Este arquivo serve como um marco de estabilidade solicitado pelo usuário.*
