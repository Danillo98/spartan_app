# Estrutura de Bloqueio por Inadimplência ('BLOQUEIO')

Este documento detalha a arquitetura implementada para bloquear o acesso de usuários inadimplentes. Esta estrutura foi projetada originalmente para Alunos, mas deve ser replicada futuramente para bloquear Administradores que não pagarem o plano mensal do sistema.

## 1. Lógica de Negócio (Service Layer)

A validação central fica no serviço financeiro (`FinancialService`).

**Conceito:**
- Verifica se o dia atual é posterior ao dia de vencimento configurado.
- Verifica se existe um pagamento (entrada financeira) registrado para o mês/ano corrente.
- Se (Dia > Vencimento) E (Não Pagou) = **BLOQUEADO**.

**Exemplo de Implementação (`FinancialService.isOverdue`):**
```dart
static Future<bool> isOverdue({
  required String userId,
  required String cnpjContext,
  int? paymentDueDay,
}) async {
  if (paymentDueDay == null) return false;

  final now = DateTime.now();
  
  // Se ainda não venceu hoje, libera
  if (now.day <= paymentDueDay) return false;

  // Busca pagamento neste mês
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0);

  final payment = await _client
      .from('financial_transactions') // ou tabela de pagamentos do admin
      .select()
      .eq('related_user_id', userId) // ou 'cnpj_academia' para admins
      .gte('transaction_date', startOfMonth.toIso8601String())
      .lte('transaction_date', endOfMonth.toIso8601String())
      .maybeSingle();

  // Se payment == null, está vencido (true)
  return payment == null;
}
```

## 2. Camada de Proteção 1: Login

Impede que o usuário entre no aplicativo.

**Local:** `RoleLoginScreen` (após `AuthService.signIn`).

**Fluxo:**
1.  Usuário digita credenciais e o Auth valida.
2.  Antes de navegar para a Home, chama o serviço de verificação financeira.
3.  Se `isOverdue` for `true`:
    *   Executa `AuthService.signOut()`.
    *   Exibe Dialog/Alert de bloqueio.
    *   Retorna sem navegar.

## 3. Camada de Proteção 2: Sessão Ativa (Dashboard)

Impede que usuários já logados (token salvo) acessem o app ao reabrir.

**Local:** `Dashboard` (no `initState` ou `_loadUserData`).

**Fluxo:**
1.  Ao carregar os dados do usuário (`getCurrentUserData`).
2.  Chama a verificação financeira.
3.  Se `isOverdue` for `true`:
    *   Exibe Dialog persistente (`barrierDismissible: false`).
    *   Ao clicar em "Entendi" ou tentar fechar, executa `AuthService.signOut()` e redireciona para Login.

---

## Adaptação para Administradores (Futuro)

Para aplicar isso ao Administrador (SaaS):

1.  **Tabela de Controle:** Criar uma tabela (ex: `saas_payments`) para registrar os pagamentos que o Admin faz para você.
2.  **User Service:** Adicionar campo `subscription_due_day` na tabela `users_adm`.
3.  **App Start:** No `main.dart` ou `AdminDashboard`, implementar a **Camada 2** checando a tabela `saas_payments`.
4.  **Login:** No `RoleLoginScreen` (case Admin), implementar a **Camada 1**.
