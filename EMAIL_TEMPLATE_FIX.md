# 🔧 CORREÇÃO: Como Configurar o Template Corretamente

## ❌ PROBLEMA IDENTIFICADO

Você configurou o template em **"Confirm signup"**, mas deveria ser em **"Magic Link"**.

---

## ✅ SOLUÇÃO: PASSO A PASSO CORRETO

### **PASSO 1: Ir para o Local Correto**

1. Vá em: **Authentication** → **Email Templates**
2. **NÃO** selecione "Confirm signup"
3. ✅ **Selecione: "Magic Link"** (ou "OTP")

---

### **PASSO 2: Configurar o Template**

#### **No campo "Subject" (Assunto):**
```
🔐 Seu código de verificação - Spartan App
```

#### **No campo "Body" (Corpo):**

Cole EXATAMENTE este código:

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
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);">
          
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%); padding: 40px 20px; text-align: center;">
              <h1 style="color: #ffffff; font-size: 32px; font-weight: bold; letter-spacing: 2px; margin: 0;">
                ⚡ SPARTAN APP
              </h1>
            </td>
          </tr>
          
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <h2 style="font-size: 18px; color: #333333; margin: 0 0 20px 0;">
                Olá! 👋
              </h2>
              
              <p style="font-size: 16px; color: #666666; line-height: 1.6; margin: 0 0 30px 0;">
                Você está a um passo de completar seu cadastro no <strong>Spartan App</strong>.
                Use o código abaixo para verificar seu email e ativar sua conta de administrador.
              </p>
              
              <!-- Code Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 30px 0;">
                <tr>
                  <td style="background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); border: 2px solid #dee2e6; border-radius: 12px; padding: 30px; text-align: center;">
                    <p style="font-size: 14px; color: #666666; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 15px 0;">
                      Seu Código de Verificação
                    </p>
                    <p style="font-size: 48px; font-weight: bold; color: #1a1a1a; letter-spacing: 12px; font-family: 'Courier New', monospace; margin: 0;">
                      {{ .Token }}
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Warning -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 20px 0;">
                <tr>
                  <td style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; border-radius: 4px;">
                    <p style="font-size: 14px; color: #856404; margin: 0;">
                      <strong>⏰ Atenção:</strong> Este código expira em <strong>10 minutos</strong>.
                    </p>
                  </td>
                </tr>
              </table>
              
              <p style="font-size: 16px; color: #666666; line-height: 1.6; margin: 20px 0 0 0;">
                Se você não solicitou este código, ignore este email.
                Sua conta permanecerá segura.
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 30px; text-align: center; border-top: 1px solid #dee2e6;">
              <p style="font-size: 14px; color: #6c757d; margin: 5px 0;">
                <strong>Spartan App</strong>
              </p>
              <p style="font-size: 14px; color: #6c757d; margin: 5px 0;">
                Sistema de Gerenciamento de Academia
              </p>
              <p style="font-size: 14px; color: #6c757d; margin: 20px 0 5px 0;">
                Este é um email automático. Por favor, não responda.
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

### **PASSO 3: Salvar**

1. Clique em **Save** (Salvar)
2. ✅ Pronto!

---

## 🎯 CHECKLIST

Antes de testar, verifique:

- [ ] Está em **"Magic Link"** (não "Confirm signup")
- [ ] Assunto está em português
- [ ] Template HTML foi colado completo
- [ ] Tem `{{ .Token }}` no código (não `{{ .Code }}`)
- [ ] Clicou em **Save**

---

## 🧪 TESTAR

1. Cadastre um novo administrador
2. Verifique seu email
3. ✅ Deve receber email customizado

---

## ⚠️ IMPORTANTE

### **Por que "Magic Link" e não "Confirm signup"?**

- **"Confirm signup"**: Usado quando Supabase cria a conta automaticamente
- **"Magic Link"**: Usado para OTP (One-Time Password) - nosso caso!

Como estamos usando `signInWithOtp()`, o Supabase usa o template de **"Magic Link"**.

---

## 📸 ONDE CLICAR

```
Dashboard
  └── Authentication
       └── Email Templates
            ├── ❌ Confirm signup (NÃO é aqui)
            ├── ✅ Magic Link (É AQUI!)
            ├── Change Email Address
            └── Reset Password
```

---

## 🔄 SE JÁ CONFIGUROU ERRADO

1. Vá em "Confirm signup"
2. Pode deixar como está (não vai ser usado)
3. Vá em **"Magic Link"**
4. Configure lá
5. Teste novamente

---

**Agora sim vai funcionar!** 🎉
