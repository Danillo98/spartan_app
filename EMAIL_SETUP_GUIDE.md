# 📧 Configuração de Email Customizado - Spartan App

## ✅ O QUE FOI IMPLEMENTADO

### **Email Customizado em Português**
- ✅ Template profissional em HTML
- ✅ Nome "Spartan App" (não mais Supabase)
- ✅ Código de 4 dígitos destacado
- ✅ Design moderno e responsivo
- ✅ Mensagens em português
- ✅ Removido código de teste do SnackBar

---

## 📁 ARQUIVOS CRIADOS/MODIFICADOS

### **1. Edge Function** (Novo)
`supabase/functions/send-verification-email/index.ts`
- Envia email customizado
- Template em HTML
- Usa Resend API

### **2. Serviço Atualizado**
`lib/services/email_verification_service.dart`
- Chama Edge Function
- Remove código de teste
- Adiciona parâmetro `userName`

### **3. Tela Atualizada**
`lib/screens/email_verification_screen.dart`
- Remove SnackBar de código de teste
- Experiência limpa

---

## 🚀 CONFIGURAÇÃO PASSO A PASSO

### **Pré-requisitos:**
- ✅ Conta no Supabase
- ✅ Supabase CLI instalado
- ✅ Conta no Resend (gratuita)

---

### **PASSO 1: Criar Conta no Resend**

1. Acesse [resend.com](https://resend.com)
2. Crie uma conta gratuita
3. Verifique seu email
4. Vá em **API Keys**
5. Crie uma nova API Key
6. **Copie a chave** (ex: `re_123abc...`)

**Plano Gratuito:**
- ✅ 100 emails/dia
- ✅ 3.000 emails/mês
- ✅ Suficiente para começar

---

### **PASSO 2: Instalar Supabase CLI**

#### **Windows:**
```powershell
# Usando Scoop
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

#### **macOS:**
```bash
brew install supabase/tap/supabase
```

#### **Linux:**
```bash
brew install supabase/tap/supabase
```

---

### **PASSO 3: Fazer Login no Supabase CLI**

```bash
# Login
supabase login

# Vincular ao projeto
supabase link --project-ref SEU_PROJECT_REF
```

**Como encontrar PROJECT_REF:**
1. Vá no [Supabase Dashboard](https://supabase.com/dashboard)
2. Selecione seu projeto
3. Vá em **Settings** → **General**
4. Copie o **Reference ID**

---

### **PASSO 4: Configurar Variável de Ambiente**

```bash
# Adicionar API Key do Resend
supabase secrets set RESEND_API_KEY=re_sua_chave_aqui
```

---

### **PASSO 5: Deploy da Edge Function**

```bash
# Navegar até a pasta do projeto
cd c:\Users\Danillo\.gemini\antigravity\scratch\spartan_app

# Deploy da função
supabase functions deploy send-verification-email
```

**Saída esperada:**
```
Deploying send-verification-email (project ref: xxx)
Bundled send-verification-email in 234ms
Deployed send-verification-email in 1.2s
```

---

### **PASSO 6: Testar a Função**

```bash
# Testar localmente
supabase functions serve send-verification-email

# Em outro terminal, testar
curl -i --location --request POST 'http://localhost:54321/functions/v1/send-verification-email' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"email":"seu@email.com","code":"1234","name":"Teste"}'
```

---

### **PASSO 7: Configurar Domínio no Resend (Opcional)**

Para usar seu próprio domínio (ex: `noreply@spartangym.com`):

1. Vá em **Domains** no Resend
2. Clique em **Add Domain**
3. Digite seu domínio (ex: `spartangym.com`)
4. Adicione os registros DNS fornecidos
5. Aguarde verificação

**Enquanto isso:**
- Use o domínio padrão do Resend
- Emails virão de `onboarding@resend.dev`

---

## 📧 TEMPLATE DE EMAIL

### **Como Fica o Email:**

```
┌─────────────────────────────────────┐
│     ⚡ SPARTAN APP                  │
│     (Fundo preto gradiente)         │
└─────────────────────────────────────┘

Olá, João! 👋

Você está a um passo de completar seu 
cadastro no Spartan App.

Use o código abaixo para verificar seu 
email e ativar sua conta de administrador.

┌─────────────────────────────────────┐
│   SEU CÓDIGO DE VERIFICAÇÃO         │
│                                     │
│         1 2 3 4                     │
│   (Grande, em negrito)              │
└─────────────────────────────────────┘

⏰ Atenção: Este código expira em 10 minutos.

Se você não solicitou este código, 
ignore este email.

─────────────────────────────────────
Spartan App
Sistema de Gerenciamento de Academia
```

---

## 🔧 PERSONALIZAÇÃO

### **Alterar Nome do Remetente:**

Edite `supabase/functions/send-verification-email/index.ts`:

```typescript
from: 'Spartan Gym <noreply@spartangym.com>',
// ou
from: 'Seu Nome <noreply@seudominio.com>',
```

### **Alterar Cores:**

No template HTML, procure por:

```css
background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%);
```

Altere para suas cores.

### **Adicionar Logo:**

```html
<div class="header">
  <img src="https://seudominio.com/logo.png" alt="Logo" style="width: 150px;">
  <div class="logo">SPARTAN APP</div>
</div>
```

---

## 🧪 TESTE

### **Teste 1: Cadastro de Admin**
1. Preencha formulário de cadastro
2. Clique em "CADASTRAR"
3. ✅ Deve receber email em português
4. ✅ Email deve vir de "Spartan App"
5. ✅ Código deve estar destacado

### **Teste 2: Reenviar Código**
1. Na tela de verificação
2. Clique em "Reenviar"
3. ✅ Deve receber novo email
4. ✅ Código anterior deve ser invalidado

### **Teste 3: Código Expirado**
1. Aguarde 10 minutos
2. Tente usar código antigo
3. ✅ Deve mostrar "Código expirado"

---

## ⚠️ TROUBLESHOOTING

### **Erro: "Function not found"**
```bash
# Verificar se função foi deployada
supabase functions list

# Re-deploy
supabase functions deploy send-verification-email
```

### **Erro: "RESEND_API_KEY not set"**
```bash
# Verificar secrets
supabase secrets list

# Adicionar novamente
supabase secrets set RESEND_API_KEY=sua_chave
```

### **Email não chega:**
1. Verifique spam/lixo eletrônico
2. Verifique logs da função:
```bash
supabase functions logs send-verification-email
```
3. Verifique dashboard do Resend

### **Erro de CORS:**
Já está configurado na Edge Function. Se persistir:
```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
```

---

## 💰 CUSTOS

### **Resend:**
- **Gratuito**: 100 emails/dia, 3.000/mês
- **Pro**: $20/mês - 50.000 emails/mês
- **Enterprise**: Customizado

### **Supabase:**
- **Gratuito**: 500.000 invocações/mês
- Edge Functions incluídas

### **Total para começar:**
- ✅ **R$ 0,00** (planos gratuitos)

---

## 📊 MONITORAMENTO

### **Ver Logs:**
```bash
# Logs em tempo real
supabase functions logs send-verification-email --tail

# Últimos 100 logs
supabase functions logs send-verification-email --limit 100
```

### **Dashboard Resend:**
- Emails enviados
- Taxa de entrega
- Bounces/Rejeições
- Aberturas (se configurado)

---

## 🎯 PRÓXIMOS PASSOS

1. ✅ Configurar Resend
2. ✅ Deploy da Edge Function
3. ✅ Testar envio de email
4. ⏳ Configurar domínio próprio (opcional)
5. ⏳ Personalizar template
6. ⏳ Monitorar entregas

---

## 📚 REFERÊNCIAS

- [Resend Docs](https://resend.com/docs)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Supabase CLI](https://supabase.com/docs/guides/cli)

---

**Implementado por**: Antigravity AI  
**Data**: 2026-01-15  
**Versão**: 1.0  
**Status**: ✅ Pronto para configurar
