# 📧 Como Mudar o Nome do Remetente de "Supabase Auth" para "Spartan App"

## 🎯 SOLUÇÃO

O nome "Supabase Auth" vem da configuração padrão do Supabase. Para mudar para "Spartan App":

### **OPÇÃO 1: Configurar no Dashboard (Projetos Pagos)**

1. Acesse: https://supabase.com/dashboard
2. Vá em **Project Settings** → **Auth**
3. Procure por **"SMTP Settings"** ou **"Email Settings"**
4. Configure:
   - **Sender Name:** `Spartan App`
   - **Sender Email:** `noreply@seu-dominio.com` (se tiver domínio próprio)

⚠️ **IMPORTANTE:** Esta opção só está disponível em planos pagos do Supabase.

---

### **OPÇÃO 2: Configurar no Template de Email (GRATUITO)**

Como você está no plano gratuito, o nome do remetente será sempre "Supabase Auth", MAS você pode deixar bem claro no template que é do Spartan App:

1. Acesse: https://supabase.com/dashboard
2. Vá em **Authentication** → **Email Templates**
3. Selecione **"Confirm signup"**
4. No campo **Subject**, coloque:
   ```
   ⚡ Spartan App - Confirme seu Cadastro
   ```

Isso fará com que o assunto do email seja bem claro, mesmo que o remetente seja "Supabase Auth".

---

### **OPÇÃO 3: Configurar SMTP Customizado (RECOMENDADO para Produção)**

Para ter controle total do nome do remetente, você pode configurar um SMTP próprio:

#### **A) Usando Gmail (GRATUITO até 500 emails/dia)**

1. No Supabase Dashboard, vá em **Project Settings** → **Auth**
2. Ative **"Enable Custom SMTP"**
3. Configure:
   ```
   SMTP Host: smtp.gmail.com
   SMTP Port: 587
   SMTP User: seu-email@gmail.com
   SMTP Password: [Senha de App do Gmail]
   Sender Name: Spartan App
   Sender Email: seu-email@gmail.com
   ```

4. Para criar senha de app no Gmail:
   - Acesse: https://myaccount.google.com/apppasswords
   - Crie uma senha de app
   - Use essa senha no SMTP Password

#### **B) Usando SendGrid (GRATUITO até 100 emails/dia)**

1. Crie conta em: https://sendgrid.com
2. Crie uma API Key
3. No Supabase, configure:
   ```
   SMTP Host: smtp.sendgrid.net
   SMTP Port: 587
   SMTP User: apikey
   SMTP Password: [Sua API Key do SendGrid]
   Sender Name: Spartan App
   Sender Email: noreply@seu-dominio.com
   ```

#### **C) Usando Resend (GRATUITO até 3000 emails/mês)**

1. Crie conta em: https://resend.com
2. Verifique seu domínio
3. Configure no Supabase

---

## 💡 RECOMENDAÇÃO

**Para desenvolvimento/teste:**
- Use o SMTP padrão do Supabase (atual)
- Deixe o assunto bem claro: "⚡ Spartan App - Confirme seu Cadastro"

**Para produção:**
- Configure SMTP customizado (Gmail ou SendGrid)
- Assim você terá controle total do nome do remetente

---

## 🎯 PRÓXIMO PASSO

Por enquanto, vou atualizar o **Subject** do email para deixar bem claro que é do Spartan App.

Depois, quando você quiser colocar em produção, podemos configurar um SMTP customizado.
