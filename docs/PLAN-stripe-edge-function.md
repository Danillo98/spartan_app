# PLAN-stripe-edge-function.md

> **Status:** Draft
> **Author:** Antigravity (Project Planner)
> **Goal:** Restaurar e implementar Edge Function do Stripe v2 para checkout seguro sem persistência prévia de dados sensíveis.

---

## 🏗️ Phase 1: Context & Requirements

### The Problem
O usuário deseja um fluxo de cadastro onde os dados Admin (Nome, Academia, CNPJ) e Auth sejam salvos definitivamente **apenas após o pagamento confirmado**.
- Dados sensíveis não devem sujar o banco `users_adm` se o usuário desistir no checkout.
- Edge Functions foram excluídas anteriormente e precisam ser recriadas.
- Segurança é prioridade (Keys não expostas no client).

### The Solution (Architecture)
1.  **Frontend (Flutter)**:
    - Coleta dados.
    - Cria Auth User (apenas Auth).
    - Chama Edge Function enviando `priceId` + `userId` + `metadata` (dados do form).
2.  **Edge Function (`create-checkout-session`)**:
    - Recebe dados.
    - Cria Sessão no Stripe contendo os Metadados.
    - Retorna URL de Checkout.
3.  **Stripe**:
    - Processa pagamento.
    - Dispara Webhook `checkout.session.completed`.
4.  **Edge Function (Webhook Handler)**:
    - Recebe evento do Stripe.
    - Lê metadados (incluindo dados do form que "viajaram" com o pagamento).
    - Insere dados na tabela `users_adm`, `academies`, e libera acesso.

---

## 📋 Phase 2: Action Plan

### Step 1: Restoration (Edge Function)
- [ ] Criar diretório `supabase/functions/create-checkout-session`.
- [ ] Restaurar código `index.ts` (v2 com melhor tratamento de erro).
- [ ] Criar arquivo `deno.json` para dependências (evita erros de import).

### Step 2: Environment Configuration
- [ ] Configurar Secrets no Supabase:
    - `STRIPE_SECRET_KEY` (sk_test_...)
    - `STRIPE_WEBHOOK_SECRET` (whsec_...) - *Necessário para o passo 4*.

### Step 3: Frontend Integration
- [ ] Validar `PaymentService.dart` (já criado, validar integração com URL real).
- [ ] Ajustar `AdminRegisterScreen` (já ajustado, validar fluxo de erro).

### Step 4: Webhook Implementation (Crucial)
- [ ] Criar nova Edge Function `stripe-webhook`.
- [ ] Implementar lógica:
    - Verificar assinatura do Stripe (Segurança).
    - Extrair `metadata` do evento.
    - Executar SQL de inserção (usando `supabase-js` client dentro da function).
    - Enviar email de boas-vindas (opcional).

### Step 5: Testing Procedure (Local)
1.  Iniciar Supabase local: `supabase start`.
2.  Iniciar Edge Functions local: `supabase functions serve`.
3.  Iniciar Stripe Trigger local (simular webhook): `stripe trigger checkout.session.completed`.
4.  Rodar App Flutter apontando para localhost.

---

## 🧑‍💻 Agent Assignments

| Agent | Task |
|-------|------|
| `backend-specialist` | Recriar `create-checkout-session` e `stripe-webhook`. |
| `database-architect` | Garantir que RLS permita inserção via Service Role (Webhook). |
| `frontend-specialist` | Validar tratamento de erros na UI durante o redirecionamento. |

---

## ✅ Verification Checklist

- [ ] Edge Function `create-checkout-session` retorna URL válida?
- [ ] Link de pagamento redireciona para Stripe?
- [ ] Metadados (Nome, CNPJ) aparecem no Painel do Stripe após pagamento?
- [ ] Webhook insere dados no `users_adm` corretamente?
- [ ] Usuário recebe feedback visual no App?
