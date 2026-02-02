# PONTO DE RESTAURAÇÃO: BLOCK
Data: 2026-02-02
Status: LIMITES DO PLANO PRATA ATUALIZADOS E BLOQUEIO AUTOMÁTICO IMPLEMENTADO.

## Estado Atual
Refinamento dos limites do plano Prata e implementação de segurança no banco para respeitar os limites de usuários por plano.

### Melhorias Realizadas
1.  **Plano Prata (Limite Reduzido):**
    -   Atualizado limite visual na Landing Page (`bem-vindo.html`) de 250 para 200 alunos.
    -   Atualizado texto informativo no App Flutter (`admin_register_screen.dart`).

2.  **Segurança de Limites (Banco de Dados):**
    -   Criada migração `20260202_enforce_plan_limits.sql`.
    -   Implementada Trigger `trg_check_plan_limit_alunos` que verifica o plano da academia antes de inserir um novo aluno.
    -   Regras: Prata (200), Ouro (500), Platina (Ilimitado).

## Arquivos Chave
-   `web/bem-vindo.html`
-   `lib/screens/admin_register_screen.dart`
-   `supabase/migrations/20260202_enforce_plan_limits.sql`
