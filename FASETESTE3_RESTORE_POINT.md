# Ponto de Restauração: FaseTeste3
Data: 13/02/2026

## Mudanças Implementadas:

1. **Avisos em Tempo Real (NoticeService):**
   - Implementação de `getActiveNoticesStream` com filtros de privacidade por papel (role) e ID de usuário específico.
   - Injeção de avisos de pagamento pendente para alunos.
   - Correção de isolamento para que nutricionistas não vejam avisos de alunos.

2. **Fuso Horário (Brasília/UTC):**
   - Padronização de todos os agendamentos (`appointments` e `training_sessions`) para salvar em **UTC**.
   - Garantia de que a exibição no app utilize o fuso horário local correto.

3. **Bloqueio de Usuário (AuthService & Main):**
   - Implementação de listeners em tempo real para `is_blocked`.
   - Popup de bloqueio imediato com logout forçado.
   - Adição de `checkBlockedStatus` proativo nos Dashboards (Admin, Aluno, Nutricionista, Treinador).

4. **Recuperação de Senha (Admin):**
   - Refatoração do `AuthService.resetPassword` para suportar o fluxo nativo do Supabase (Recovery) e o fluxo via RPC.
   - Correção de erro de Redefinição de Senha para administradores.

5. **Navegação (PopScope):**
   - Adicionado `PopScope` nas telas de Dashboard (com confirmação de logout) e telas secundárias (Meus Treinos, Minhas Dietas) para navegação nativa correta.

6. **Perfil e Imagens (ProfileService):**
   - Correção do upload de fotos para Web e PWA.
   - Robustez na compressão de imagens para garantir arquivos < 500KB.

## Estado da Aplicação:
- **Estável.** Todos os lints críticos resolvidos.
- **Pronto para teste de campo.**
