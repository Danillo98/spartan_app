# PONTO DE RESTAURAÇÃO: FERRARI
Data: 2026-01-17
Status: SISTEMA DE AUTENTICAÇÃO E CADASTRO COMPLETO E FUNCIONAL

## Estado Atual
Este ponto marca a conclusão bem-sucedida de todos os fluxos críticos de autenticação e cadastro para todos os perfis (Admin, Nutricionista, Personal, Aluno).

### Funcionalidades Validadas
1.  **Esqueci Minha Senha (Todos os Perfis):**
    - Implementado `check_email_exists` via RPC segura (bypassa RLS apenas para verificação true/false).
    - Busca de e-mail Case-Insensitive (`ilike`) em todas as 4 tabelas.
    - Botão "Esqueci minha senha" visível e funcional em todas as telas de login.

2.  **Cadastro de Usuários (Pelo Admin):**
    - `UserService.createUserByAdmin` agora usa um `SupabaseClient` temporário com fluxo `implicit`.
    - Isso permite:
        - Enviar o e-mail de confirmação real para o novo usuário.
        - Manter o Administrador **LOGADO** durante o processo (sem logout forçado).
        - Evitar erros de PKCE/AsyncStorage.

3.  **Confirmação de Email (Deep Link):**
    - `EmailConfirmationScreen` foi corrigido para **SEMPRE** processar o token customizado.
    - Mesmo se o Supabase SDK autenticar automaticamente a sessão, o app agora extrai os dados do token (Role, CPF, CNPJ) e cria o registro na tabela correta.
    - Solução robusta contra "Cadastro Incompleto".

4.  **Segurança e Banco de Dados:**
    - Script `CORRIGIR_RLS_INSERT.sql` aplicado: permite que usuários autenticados criem seus próprios registros (INSERT) nas tabelas `users_*` com segurança RLS (`auth.uid() = id`).
    - Script `CRIAR_RPC_CHECK_EMAIL.sql` aplicado: permite verificação de existência de e-mail sem expor dados.

## Arquivos Chave Alterados
- `lib/services/user_service.dart`: Client temporário, correções de fluxo.
- `lib/services/auth_service.dart`: RPC na recuperação de senha, lógica de confirmação.
- `lib/screens/role_login_screen.dart`: UI do botão "Esqueci Senha".
- `lib/screens/email_confirmation_screen.dart`: Lógica de prioridade do token customizado.
- `CORRIGIR_RLS_INSERT.sql`: Correção de permissões de banco.
- `CRIAR_RPC_CHECK_EMAIL.sql`: Função segura de verificação.

## Como Restaurar
Se necessário voltar a este ponto, certifique-se de que os scripts SQL listados acima estejam aplicados no banco de dados e reverta o código Dart para o estado atual.
