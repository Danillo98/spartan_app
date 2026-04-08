---
description: Implementação Completa do Fluxo PIX com Mercado Pago e Supabase Webhooks
---

# Integração Mercado Pago PIX (Arquitetura e Fluxo à Prova de Falhas)

Este documento registra como foi estruturado o sucesso da integração de pagamentos PIX com Mercado Pago, utilizando Supabase Edge Functions e Flutter para o Spartan App (e projetos futuros).

## 1. Edge Function: `gerar-pix`
Responsável por conectar na API do Mercado Pago e gerar o QR Code (Copia e Cola + Imagem Base64).
* Rota MP: `POST https://api.mercadopago.com/v1/payments`
* Payload deve conter:
  - `transaction_amount`
  - `description`
  - `payment_method_id: "pix"`
  - `payer: { email, identification: { type: "CPF", number: "..." } }`
  - `external_reference` (CRÍTICO: Passar o ID do usuário no banco (`userId`), pois o webhook usará isso para saber quem pagou).
  - `notification_url` (URL da Edge Function do Webhook).
* A função retorna para o app o `qr_code` e o `qr_code_base64` do bloco `point_of_interaction.transaction_data`.

## 2. Edge Function: Webhook (`webhook-mercadopago`)
Responsável por escutar o alerta assíncrono do MP quando a transferência cai na conta.
* Recebe um `POST` do Mercado Pago contendo `action` (ou `type` = 'payment') e um `data.id`.
* Usa o `data.id` para fazer um `GET https://api.mercadopago.com/v1/payments/{id}` e checar veracidade do pagamento.
* Se `status === "approved"`, usa o `external_reference` para atualizar o Banco de Dados.

### ✅ O que deve ser atualizado no DBO (Tratamento de Assinatura):
Para um fluxo limpo sem bloqueios falsos, SEMPRE atualizar as seguintes colunas juntas:
* `assinatura_status`: "active"
* `plano_mensal`: Capitalizado ("Prata", "Ouro", não minúsculas).
* `assinatura_iniciada`: `now.toISOString()` (A hora exata do pagamento).
* `assinatura_expirada`: `now + 30 dias`
* `assinatura_deletada`: `now + 90 dias` (Prazo de deleção da conta inativa).
* `is_blocked`: `false` (CRÍTICO: Destranca o usuário que renovou o plano depois que a conta já estava bloqueada).

## 3. Tela Flutter (App): `PixCheckoutScreen`
Responsável por exibir o QRCode e esperar a confirmação.

### 🛑 O Problema do Escutador (Falha Inicial vs Correção)
* **Erro Comum:** Usar WebSockets padrão (`stream()`) ou apenas olhar a flag `active`. Se um usuário com a conta válida quiser adiantar uma renovação, o painel libera imediatamente pois ele já era `active`.
* **Solução de Ouro (Data Tracking + Polling):**
  1. No momento de carregar a tela, busque e salve a data atual de `assinatura_expirada` (exemplo: `A_Velha`).
  2. Implemente o Monitoramento por **Polling via `Timer.periodic` a cada 4 segundos** (muito mais à prova de quedas de rede do que sockets).
  3. No Polling, a condição para exibir a "Tela Verde de Sucesso" deve ser estrita:
     ```dart
      bool isNowActive = (status == 'active');
      bool isExpirationRenewed = (novaDataExpiracao != A_Velha);

      if (isNowActive && isExpirationRenewed) {
         // O WEBHOOK MUDOU OS DIAS NO BANCO: MENSAGEM DE SUCESSO APROVADA!
      }
     ```

## 4. O Redirecionamento Final
Após sucesso na tela PIX:
- Feche a tela de diálogo.
- Substitua a rota ativamente removendo histórico viciado `/admin/home` se ele for dinâmico:
  `Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const Dashboard()), (route) => false);`
- Rode no fundo a rotina `AuthService.checkBlockedStatus()` ou reler a Database para eliminar velhos caches das limitações. 
