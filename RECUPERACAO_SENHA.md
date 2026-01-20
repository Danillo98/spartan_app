# 🔐 Recuperação de Senha - Spartan App

## ✅ FUNCIONALIDADE IMPLEMENTADA

Sistema completo de recuperação de senha para administradores usando email.

---

## 📋 O QUE FOI CRIADO:

### **1. Telas:**
- ✅ `forgot_password_screen.dart` - Tela para solicitar recuperação
- ✅ `reset_password_screen.dart` - Tela para redefinir a senha

### **2. Serviços:**
- ✅ `AuthService.sendPasswordResetEmail()` - Envia email de recuperação
- ✅ `AuthService.resetPassword()` - Redefine a senha

### **3. Integração:**
- ✅ Botão "Esqueci minha senha" na tela de login do admin
- ✅ Deep link configurado para processar reset de senha
- ✅ Listener de autenticação atualizado

---

## 🎯 COMO FUNCIONA:

### **Fluxo Completo:**

```
1. Admin clica em "Esqueci minha senha" na tela de login
   ↓
2. Digite o email cadastrado
   ↓
3. Clica em "ENVIAR LINK DE RECUPERAÇÃO"
   ↓
4. Sistema verifica se email existe
   ↓
5. Supabase envia email com link de recuperação
   ↓
6. Admin abre email e clica no link
   ↓
7. Link abre o app automaticamente (deep link)
   ↓
8. Tela de redefinir senha aparece
   ↓
9. Admin digita nova senha (mínimo 6 caracteres)
   ↓
10. Confirma a nova senha
   ↓
11. Clica em "REDEFINIR SENHA"
   ↓
12. Senha é atualizada no Supabase
   ↓
13. Mensagem de sucesso aparece
   ↓
14. Redireciona para tela de login
   ↓
15. Admin faz login com a nova senha! ✅
```

---

## 🔧 CONFIGURAÇÃO NECESSÁRIA:

### **1. Configurar Redirect URL no Supabase:**

1. Acesse: https://supabase.com/dashboard
2. Selecione seu projeto
3. Vá em **Authentication** → **URL Configuration**
4. Em **"Redirect URLs"**, adicione:
   ```
   io.supabase.spartanapp://reset-password
   ```
5. Clique em **"Save"**

### **2. Configurar Template de Email (Opcional):**

Por padrão, o Supabase envia um email genérico. Para personalizar:

1. Vá em **Authentication** → **Email Templates**
2. Selecione **"Reset Password"**
3. Personalize o template HTML
4. Use a variável `{{ .ConfirmationURL }}` para o link

**Exemplo de template:**
```html
<h2>Redefinir Senha - Spartan App</h2>
<p>Olá!</p>
<p>Você solicitou a redefinição de senha.</p>
<p>Clique no botão abaixo para criar uma nova senha:</p>
<a href="{{ .ConfirmationURL }}">REDEFINIR SENHA</a>
<p>Este link expira em 1 hora.</p>
<p>Se você não solicitou isso, ignore este email.</p>
```

---

## 📱 COMO USAR:

### **Para o Administrador:**

1. **Na tela de login:**
   - Clique em **"Esqueci minha senha"** (abaixo do campo de senha)

2. **Na tela de recuperação:**
   - Digite seu email cadastrado
   - Clique em **"ENVIAR LINK DE RECUPERAÇÃO"**
   - Aguarde mensagem de confirmação

3. **No email:**
   - Abra o email recebido
   - Verifique também a pasta de SPAM
   - Clique no link de recuperação

4. **No app (após clicar no link):**
   - Digite sua nova senha (mínimo 6 caracteres)
   - Confirme a nova senha
   - Clique em **"REDEFINIR SENHA"**

5. **Fazer login:**
   - Volte para a tela de login
   - Use seu email e a nova senha

---

## 🔒 SEGURANÇA:

### **Recursos de Segurança Implementados:**

1. ✅ **Validação de Email:**
   - Verifica se o email existe antes de enviar
   - Não revela se o email está cadastrado (por segurança)

2. ✅ **Token Temporário:**
   - Link expira em 1 hora
   - Token único por solicitação
   - Não pode ser reutilizado

3. ✅ **Validação de Senha:**
   - Mínimo 6 caracteres
   - Confirmação de senha obrigatória
   - Senhas devem coincidir

4. ✅ **Deep Link Seguro:**
   - Usa protocolo personalizado do app
   - Token não fica exposto na URL

5. ✅ **Logout Automático:**
   - Após redefinir senha, usuário é deslogado
   - Precisa fazer login novamente com nova senha

---

## 🧪 TESTE:

### **Teste 1: Solicitar Recuperação**
1. Vá para tela de login do admin
2. Clique em "Esqueci minha senha"
3. Digite email válido
4. ✅ Deve mostrar mensagem de sucesso
5. ✅ Email deve chegar (verifique SPAM)

### **Teste 2: Email Inválido**
1. Digite email que não existe
2. ✅ Deve mostrar mensagem de sucesso (por segurança)
3. ✅ Email não deve ser enviado

### **Teste 3: Redefinir Senha**
1. Clique no link do email
2. ✅ App deve abrir automaticamente
3. ✅ Tela de redefinir senha deve aparecer
4. Digite nova senha
5. Confirme a senha
6. ✅ Deve mostrar "Senha Redefinida!"
7. ✅ Deve redirecionar para login

### **Teste 4: Validação de Senha**
1. Tente senha com menos de 6 caracteres
2. ✅ Deve mostrar erro
3. Tente senhas diferentes na confirmação
4. ✅ Deve mostrar "As senhas não coincidem"

### **Teste 5: Login com Nova Senha**
1. Após redefinir, faça login
2. Use email e nova senha
3. ✅ Deve fazer login com sucesso

---

## ⚠️ TROUBLESHOOTING:

### **Email não chega:**
- Verifique pasta de SPAM
- Aguarde até 2 minutos
- Verifique se email está correto
- Verifique configuração SMTP do Supabase

### **Link não abre o app:**
- Verifique se deep link está configurado
- Recompile o app: `flutter clean && flutter run`
- Verifique Redirect URLs no Supabase
- Tente clicar no link novamente

### **Erro ao redefinir senha:**
- Verifique se link não expirou (1 hora)
- Verifique se senha tem mínimo 6 caracteres
- Tente solicitar novo link

### **"Email já cadastrado" ao fazer login:**
- Isso significa que a senha foi redefinida
- Use a nova senha que você criou
- Se esqueceu, solicite nova recuperação

---

## 📊 LOGS DE DEBUG:

Ao usar a funcionalidade, você verá logs no console:

```
📧 Enviando email de recuperação para: admin@email.com
✅ Email de recuperação enviado com sucesso

🔔 Auth Event: signedIn
📝 Type: recovery
🔐 Processando reset de senha...

🔐 Redefinindo senha...
✅ Senha redefinida com sucesso
```

---

## 🎨 DESIGN:

### **Tela de Recuperação:**
- ✅ Ícone de cadeado com reset
- ✅ Título "Esqueceu sua senha?"
- ✅ Descrição clara
- ✅ Campo de email com validação
- ✅ Botão com loading
- ✅ Dialog de confirmação

### **Tela de Redefinir:**
- ✅ Ícone de cadeado aberto
- ✅ Título "Nova Senha"
- ✅ 2 campos de senha (nova e confirmar)
- ✅ Botão mostrar/ocultar senha
- ✅ Dica de segurança
- ✅ Validação em tempo real
- ✅ Dialog de sucesso

### **Cores:**
- Tema preto (admin): `Colors.blueGrey[900]`
- Gradiente suave
- Botões com sombra
- Feedback visual claro

---

## 🔄 LIMITAÇÕES:

### **Apenas para Administradores:**
- Botão só aparece na tela de login do admin
- Outros perfis não têm acesso
- Para adicionar a outros perfis, remova a condição:
  ```dart
  if (widget.role == UserRole.admin)
  ```

### **Expiração do Link:**
- Link expira em 1 hora (padrão Supabase)
- Não pode ser alterado facilmente
- Usuário precisa solicitar novo link se expirar

### **Email Único:**
- Cada solicitação invalida a anterior
- Apenas o link mais recente funciona

---

## 🚀 PRÓXIMOS PASSOS (Opcional):

### **Melhorias Futuras:**

1. **Adicionar para outros perfis:**
   - Nutricionista
   - Personal Trainer
   - Aluno

2. **Histórico de Recuperações:**
   - Registrar tentativas
   - Alertar sobre múltiplas tentativas
   - Bloquear após X tentativas

3. **Autenticação em 2 Fatores:**
   - Código SMS
   - Código por email
   - Autenticador (Google Authenticator)

4. **Notificações:**
   - Avisar quando senha for alterada
   - Email de confirmação de mudança

5. **Validação de Senha Forte:**
   - Exigir letras maiúsculas
   - Exigir números
   - Exigir símbolos
   - Verificar senhas comuns

---

## 📝 RESUMO:

✅ **Implementado:**
- Tela de solicitar recuperação
- Tela de redefinir senha
- Envio de email automático
- Deep link configurado
- Validação de segurança
- Feedback visual completo

✅ **Funciona:**
- Apenas para administradores
- Email via Supabase
- Link expira em 1 hora
- Senha mínima 6 caracteres

✅ **Pronto para uso:**
- Basta configurar Redirect URL no Supabase
- Testar fluxo completo
- Personalizar template de email (opcional)

---

**Desenvolvido por**: Antigravity AI  
**Data**: 2026-01-16  
**Versão**: 1.0  
**Status**: ✅ Pronto para uso!
