# 🎯 GUIA PASSO A PASSO - Configurar Template de Email

## 📍 ONDE ENCONTRAR NO SUPABASE

### **PASSO 1: Fazer Login**

1. Acesse: https://supabase.com/dashboard
2. Faça login com sua conta
3. Você verá a lista dos seus projetos

---

### **PASSO 2: Selecionar Projeto**

1. Clique no seu projeto (o nome do seu app)
2. Você será levado para o dashboard do projeto

---

### **PASSO 3: Ir para Authentication**

**LOCALIZAÇÃO:**
- No menu lateral ESQUERDO
- Procure o ícone de **cadeado** 🔒
- Clique em **"Authentication"**

```
Menu Lateral:
├── 🏠 Home
├── 📊 Table Editor
├── 🔒 Authentication  ← CLIQUE AQUI!
├── 🗄️ Storage
├── 📡 Edge Functions
└── ⚙️ Settings
```

---

### **PASSO 4: Ir para Email Templates**

Depois de clicar em "Authentication":

1. Você verá um **submenu** na parte superior
2. Procure por **"Email Templates"**
3. Clique nele

```
Submenu Authentication:
┌─────────────────────────────────────┐
│ Users | Policies | Providers |     │
│ Email Templates ← CLIQUE AQUI!      │
└─────────────────────────────────────┘
```

**OU**

Se não aparecer no submenu, procure na **barra lateral**:

```
Authentication (expandido):
├── Users
├── Policies  
├── Providers
├── Email Templates  ← CLIQUE AQUI!
└── Settings
```

---

### **PASSO 5: Selecionar Template "Confirm signup"**

Você verá uma lista de templates:

```
Email Templates:
├── Invite user
├── Magic Link
├── Change Email Address
├── Reset Password
└── Confirm signup  ← SELECIONE ESTE!
```

**IMPORTANTE:** Clique em **"Confirm signup"** (não "Magic Link")!

---

### **PASSO 6: Editar o Template**

Você verá 2 campos:

#### **Campo 1: Subject (Assunto)**

Apague o texto atual e cole:

```
🎉 Bem-vindo ao Spartan App - Confirme seu Email
```

#### **Campo 2: Body (Corpo)**

Apague TODO o HTML atual e cole o template completo abaixo.

---

## 📧 TEMPLATE COMPLETO PARA COLAR

**COPIE TUDO ABAIXO (incluindo `<!DOCTYPE html>`):**

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);">
          
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%); padding: 50px 20px; text-align: center;">
              <h1 style="color: #ffffff; font-size: 36px; font-weight: bold; letter-spacing: 3px; margin: 0;">
                ⚡ SPARTAN APP
              </h1>
              <p style="color: #cccccc; font-size: 16px; margin: 10px 0 0 0;">
                Sistema de Gerenciamento de Academia
              </p>
            </td>
          </tr>
          
          <!-- Content -->
          <tr>
            <td style="padding: 50px 40px;">
              <h2 style="font-size: 24px; color: #333333; margin: 0 0 20px 0;">
                Bem-vindo! 🎉
              </h2>
              
              <p style="font-size: 16px; color: #666666; line-height: 1.8; margin: 0 0 30px 0;">
                Estamos muito felizes em ter você conosco! Você está a apenas um clique de ativar sua conta de <strong>Administrador</strong> no Spartan App.
              </p>
              
              <p style="font-size: 16px; color: #666666; line-height: 1.8; margin: 0 0 30px 0;">
                Para confirmar seu email e ativar sua conta, clique no botão abaixo:
              </p>
              
              <!-- Button -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 40px 0;">
                <tr>
                  <td align="center">
                    <a href="{{ .ConfirmationURL }}" style="display: inline-block; background: linear-gradient(135deg, #1a1a1a 0%, #333333 100%); color: #ffffff; text-decoration: none; padding: 18px 50px; border-radius: 12px; font-size: 18px; font-weight: bold; box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);">
                      ✅ Confirmar Meu Email
                    </a>
                  </td>
                </tr>
              </table>
              
              <!-- Alternative Link -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 30px 0;">
                <tr>
                  <td style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; border-left: 4px solid #1a1a1a;">
                    <p style="font-size: 14px; color: #666666; margin: 0 0 10px 0;">
                      <strong>Não consegue clicar no botão?</strong>
                    </p>
                    <p style="font-size: 13px; color: #666666; margin: 0;">
                      Copie e cole este link no seu navegador:
                    </p>
                    <p style="font-size: 13px; color: #0066cc; word-break: break-all; margin: 10px 0 0 0;">
                      {{ .ConfirmationURL }}
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Warning -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 30px 0;">
                <tr>
                  <td style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; border-radius: 4px;">
                    <p style="font-size: 14px; color: #856404; margin: 0;">
                      <strong>⏰ Importante:</strong> Este link expira em <strong>24 horas</strong>.
                    </p>
                  </td>
                </tr>
              </table>
              
              <p style="font-size: 16px; color: #666666; line-height: 1.8; margin: 30px 0 0 0;">
                Se você não solicitou este cadastro, pode ignorar este email com segurança.
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 40px; text-align: center; border-top: 1px solid #dee2e6;">
              <p style="font-size: 16px; color: #333333; font-weight: bold; margin: 0 0 10px 0;">
                Spartan App
              </p>
              <p style="font-size: 14px; color: #6c757d; margin: 5px 0;">
                Sistema de Gerenciamento de Academia
              </p>
              <p style="font-size: 14px; color: #6c757d; margin: 20px 0 5px 0;">
                Este é um email automático. Por favor, não responda.
              </p>
              <p style="font-size: 12px; color: #999999; margin: 20px 0 0 0;">
                © 2026 Spartan App. Todos os direitos reservados.
              </p>
            </td>
          </tr>
          
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

### **PASSO 7: Salvar**

1. Role até o final da página
2. Clique no botão **"Save"** (verde, no canto inferior direito)
3. ✅ Pronto!

---

## 🎯 RESUMO VISUAL

```
1. https://supabase.com/dashboard
   ↓
2. Selecionar seu projeto
   ↓
3. Menu lateral → 🔒 Authentication
   ↓
4. Submenu → Email Templates
   ↓
5. Selecionar → Confirm signup
   ↓
6. Subject → Colar assunto em português
   ↓
7. Body → Colar HTML completo
   ↓
8. Clicar em Save
   ↓
9. ✅ PRONTO!
```

---

## ⚠️ DICAS

### **Não encontra "Email Templates"?**

Tente:
1. Clicar em "Authentication" no menu lateral
2. Procurar na **barra superior** (abas)
3. Ou procurar em "Settings" → "Auth" → "Email Templates"

### **Não encontra "Confirm signup"?**

Procure por:
- "Confirm your signup"
- "Email confirmation"
- "Signup confirmation"

### **Ainda não encontra?**

Tire um print da tela do Supabase e me mostre, vou te ajudar a localizar!

---

## 📸 ONDE CLICAR (Descrição Visual)

```
┌─────────────────────────────────────────┐
│  SUPABASE DASHBOARD                     │
├─────────────────────────────────────────┤
│                                         │
│  Menu Lateral:                          │
│  ┌─────────────┐                        │
│  │ 🏠 Home     │                        │
│  │ 📊 Tables   │                        │
│  │ 🔒 Auth     │ ← CLIQUE AQUI          │
│  │ 🗄️ Storage  │                        │
│  │ ⚙️ Settings │                        │
│  └─────────────┘                        │
│                                         │
│  Depois de clicar em Auth:              │
│  ┌─────────────────────────────────┐    │
│  │ Users | Policies | Providers   │    │
│  │ Email Templates ← CLIQUE AQUI  │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Lista de Templates:                    │
│  • Invite user                          │
│  • Magic Link                           │
│  • Change Email                         │
│  • Reset Password                       │
│  • Confirm signup ← SELECIONE ESTE     │
│                                         │
└─────────────────────────────────────────┘
```

---

**Se ainda não conseguir encontrar, me mande um print da tela que eu te ajudo!** 📸

**Ou me diga o que você está vendo no dashboard!** 💬
