# 🔐 Guia de Configuração - Recuperação de Senha

## ✅ MUDANÇAS IMPLEMENTADAS:

### **1. Design Atualizado:**
- ✅ Telas seguem o padrão da tela de login
- ✅ Gradiente claro e suave
- ✅ Animações de fade e slide
- ✅ Tipografia Google Fonts (Cinzel + Lato)
- ✅ Cores consistentes com tema admin

### **2. Email Customizado em Português:**
- ✅ Template HTML profissional
- ✅ Gradiente preto no header
- ✅ Mensagens em português
- ✅ Avisos de segurança
- ✅ Botão estilizado

### **3. Deep Link Corrigido:**
- ✅ Página HTML intermediária (`reset-password.html`)
- ✅ Redireciona para o app automaticamente
- ✅ Botão manual caso não abra
- ✅ Tratamento de erros

---

## 🚀 PASSO A PASSO DE CONFIGURAÇÃO:

### **PASSO 1: Fazer Deploy da Página HTML**

A página `reset-password.html` precisa estar hospedada online. Vamos usar o Netlify:

1. **Acesse:** https://app.netlify.com
2. **Faça login** (use sua conta GitHub ou email)
3. **Clique em "Add new site"** → **"Deploy manually"**
4. **Arraste TODOS os arquivos da pasta `web`:**
   - `confirm.html`
   - `reset-password.html` (NOVO!)
   - `index.html`
   - `README.md`

5. **Aguarde o deploy** (~30 segundos)
6. **Copie a URL** (exemplo: `https://spartan-app.netlify.app`)

---

### **PASSO 2: Atualizar URL no Código**

Edite `lib/services/auth_service.dart` na linha ~377:

```dart
// ANTES:
redirectTo: 'https://spartan-app.netlify.app/reset-password.html',

// DEPOIS (com SUA URL do Netlify):
redirectTo: 'https://SUA-URL.netlify.app/reset-password.html',
```

**Exemplo:**
```dart
redirectTo: 'https://spartan-app-confirm.netlify.app/reset-password.html',
```

---

### **PASSO 3: Configurar Redirect URLs no Supabase**

1. Acesse: https://supabase.com/dashboard
2. Selecione seu projeto
3. Vá em **Authentication** → **URL Configuration**
4. Em **"Redirect URLs"**, adicione:
   ```
   https://SUA-URL.netlify.app/*
   io.supabase.spartanapp://*
   ```

**Exemplo:**
```
https://spartan-app-confirm.netlify.app/*
io.supabase.spartanapp://*
```

5. Clique em **"Save"**

---

### **PASSO 4: Personalizar Template de Email (Opcional)**

Se quiser usar o email customizado em português:

1. Vá em **Authentication** → **Email Templates**
2. Selecione **"Reset Password"**
3. Cole este template:

```html
<h2 style="color: #1a1a1a;">🔐 Recuperação de Senha</h2>
<p>Olá!</p>
<p>Você solicitou a redefinição de senha da sua conta de <strong>Administrador</strong> no Spartan App.</p>
<p>Clique no botão abaixo para criar uma nova senha:</p>
<a href="{{ .ConfirmationURL }}" style="background: #1a1a1a; color: white; padding: 12px 30px; text-decoration: none; border-radius: 8px; display: inline-block; margin: 20px 0;">REDEFINIR SENHA</a>
<p style="color: #ff9800;"><strong>⏰ Atenção:</strong> Este link expira em 1 hora.</p>
<p style="color: #666; font-size: 14px;">Se você não solicitou esta redefinição, ignore este email.</p>
```

4. Clique em **"Save"**

---

## 🧪 COMO TESTAR:

### **Teste Completo:**

1. **Execute o app:**
   ```bash
   flutter run
   ```

2. **Vá para tela de login do admin**

3. **Clique em "Esqueci minha senha"**

4. **Digite um email válido** (que existe no sistema)

5. **Clique em "ENVIAR LINK"**

6. **Verifique o email:**
   - Abra sua caixa de entrada
   - Verifique também SPAM
   - Aguarde até 2 minutos

7. **Clique no link do email:**
   - Deve abrir a página HTML no navegador
   - Aguarde 3 segundos
   - App deve abrir automaticamente
   - Se não abrir, clique no botão "ABRIR SPARTAN APP"

8. **No app:**
   - Tela de "Nova Senha" deve aparecer
   - Digite nova senha (mínimo 6 caracteres)
   - Confirme a senha
   - Clique em "REDEFINIR SENHA"

9. **Sucesso!**
   - Mensagem "Senha Redefinida!" aparece
   - Clique em "IR PARA LOGIN"
   - Faça login com a nova senha

---

## 📝 CHECKLIST DE CONFIGURAÇÃO:

- [ ] Página `reset-password.html` deployada no Netlify
- [ ] URL do Netlify copiada
- [ ] `auth_service.dart` atualizado com a URL
- [ ] Redirect URLs configuradas no Supabase
- [ ] Template de email personalizado (opcional)
- [ ] App recompilado (`flutter run`)
- [ ] Teste completo realizado

---

## ⚠️ TROUBLESHOOTING:

### **Email não chega:**
- Verifique SPAM
- Aguarde até 2 minutos
- Verifique se email está correto
- Verifique configuração SMTP do Supabase

### **Link abre tela preta:**
- Verifique se página HTML está deployada
- Verifique URL no `auth_service.dart`
- Verifique Redirect URLs no Supabase
- Limpe cache do navegador

### **App não abre automaticamente:**
- Aguarde 3 segundos
- Clique no botão manual "ABRIR SPARTAN APP"
- Verifique se app está instalado
- Recompile o app: `flutter clean && flutter run`

### **Erro "Token inválido":**
- Link pode ter expirado (1 hora)
- Solicite novo link
- Verifique se clicou no link mais recente

### **Erro ao redefinir senha:**
- Verifique se senha tem mínimo 6 caracteres
- Verifique se senhas coincidem
- Tente solicitar novo link

---

## 🎨 DESIGN IMPLEMENTADO:

### **Tela de Recuperação:**
- ✅ Ícone de cadeado com reset
- ✅ Título "Recuperar Senha" (Cinzel)
- ✅ Descrição clara
- ✅ Campo de email estilizado
- ✅ Botão gradiente preto
- ✅ Animações suaves
- ✅ Botão voltar

### **Tela de Redefinir:**
- ✅ Ícone de cadeado aberto
- ✅ Título "Nova Senha" (Cinzel)
- ✅ 2 campos de senha
- ✅ Botões mostrar/ocultar
- ✅ Dica de segurança
- ✅ Validação em tempo real
- ✅ Botão gradiente preto

### **Dialog de Sucesso:**
- ✅ Ícone de check verde
- ✅ Mensagens claras
- ✅ Avisos destacados
- ✅ Botão de ação

---

## 📧 EMAIL CUSTOMIZADO:

### **Características:**
- ✅ Header com gradiente preto
- ✅ Ícone de cadeado 🔐
- ✅ Logo "SPARTAN APP"
- ✅ Mensagens em português
- ✅ Botão estilizado
- ✅ Aviso de expiração (1 hora)
- ✅ Link alternativo
- ✅ Aviso de segurança
- ✅ Footer profissional

---

## 🔗 DEEP LINK:

### **Fluxo:**
```
1. Email → Link para página HTML
   ↓
2. Página HTML extrai token
   ↓
3. Redireciona para: io.supabase.spartanapp://reset-password?token=ABC123
   ↓
4. App abre automaticamente
   ↓
5. Tela de redefinir senha aparece
```

### **Fallback:**
- Se app não abrir em 3 segundos
- Botão manual aparece
- Usuário clica para abrir app

---

## 📊 ARQUIVOS CRIADOS/MODIFICADOS:

1. ✅ `lib/screens/forgot_password_screen.dart` (redesenhada)
2. ✅ `lib/screens/reset_password_screen.dart` (redesenhada)
3. ✅ `lib/services/auth_service.dart` (URL atualizada)
4. ✅ `web/reset-password.html` (NOVO)
5. ✅ `supabase/functions/send-password-reset/index.ts` (NOVO - opcional)

---

## 🎯 PRÓXIMOS PASSOS:

1. ✅ Fazer deploy no Netlify
2. ✅ Atualizar URL no código
3. ✅ Configurar Supabase
4. ✅ Testar fluxo completo
5. ⏳ Personalizar template de email (opcional)
6. ⏳ Deploy da Edge Function (opcional)

---

**TUDO PRONTO!** 🎉

Agora é só seguir os passos de configuração e testar!

---

**Desenvolvido por**: Antigravity AI  
**Data**: 2026-01-16  
**Versão**: 2.0  
**Status**: ✅ Atualizado e pronto!
