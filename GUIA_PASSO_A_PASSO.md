# 🎯 GUIA PASSO A PASSO - Resolver Problema de Email

## ⚡ AÇÃO IMEDIATA

Siga estes passos **NA ORDEM** para resolver o problema:

---

## 📋 PASSO 1: Verificar Configuração do Supabase

### 1.1 Acesse o Dashboard
```
https://supabase.com/dashboard/project/SEU_PROJETO_ID
```

### 1.2 Vá em Authentication → Settings

Procure por **"Email Auth"** e verifique:

```
✅ Enable email provider: DEVE estar ON (verde)
✅ Confirm email: DEVE estar ON (verde)  
✅ Enable email confirmations: DEVE estar ON (verde)
```

**Se algum estiver OFF (vermelho):**
1. Clique para ativar
2. Clique em "Save"
3. Aguarde 30 segundos

### 1.3 Vá em Authentication → Email Templates

1. Selecione: **"Confirm signup"**
2. Verifique se o template existe
3. Se estiver vazio ou em inglês, cole este template:

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f4f4f4;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; padding: 40px;">
          <tr>
            <td style="text-align: center;">
              <h1 style="color: #1a1a1a; margin: 0 0 20px 0;">⚡ SPARTAN APP</h1>
              <h2 style="color: #333; margin: 0 0 20px 0;">Bem-vindo! 🎉</h2>
              <p style="color: #666; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;">
                Para confirmar seu cadastro, clique no botão abaixo:
              </p>
              <a href="{{ .ConfirmationURL }}" style="display: inline-block; background: #1a1a1a; color: #ffffff; text-decoration: none; padding: 15px 40px; border-radius: 8px; font-size: 16px; font-weight: bold;">
                ✅ Confirmar Cadastro
              </a>
              <p style="color: #999; font-size: 14px; margin: 30px 0 0 0;">
                Se você não solicitou este cadastro, ignore este email.
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

4. Clique em "Save"

### 1.4 Vá em Authentication → URL Configuration

Adicione estas URLs em **"Redirect URLs"**:

```
http://localhost:3000/*
http://localhost:3000/confirm*
https://seu-dominio.com/*
```

Clique em "Save"

---

## 📋 PASSO 2: Limpar Estado Atual

### 2.1 Abra o SQL Editor do Supabase

### 2.2 Execute este comando:

```sql
-- Ver usuários existentes
SELECT id, email, email_confirmed_at, created_at 
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 10;
```

### 2.3 Se houver usuários de teste, delete:

```sql
-- CUIDADO! Isso vai deletar TODOS os usuários de teste
DELETE FROM auth.users WHERE email LIKE '%teste%';
DELETE FROM public.users WHERE email LIKE '%teste%';

-- Ou delete um email específico:
DELETE FROM auth.users WHERE email = 'seu-email@gmail.com';
DELETE FROM public.users WHERE email = 'seu-email@gmail.com';
```

---

## 📋 PASSO 3: Testar Envio de Email

### 3.1 Adicione a tela de teste ao seu app

Abra `lib/main.dart` e adicione a rota:

```dart
import 'screens/email_test_screen.dart';

// No MaterialApp, adicione:
routes: {
  '/email-test': (context) => const EmailTestScreen(),
  // ... outras rotas
},
```

### 3.2 Navegue para a tela de teste

```dart
Navigator.pushNamed(context, '/email-test');
```

Ou adicione um botão temporário na tela de login:

```dart
TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmailTestScreen()),
    );
  },
  child: const Text('🧪 Testar Email'),
)
```

### 3.3 Execute o teste

1. Digite seu **email REAL** (Gmail, Outlook, etc)
2. Clique em "📧 Testar Envio de Email"
3. Aguarde a resposta

**Resultado esperado:**
```
✅ SUCESSO!
📧 Email enviado para: seu-email@gmail.com
```

### 3.4 Verifique seu email

1. Abra seu email
2. Procure em **TODAS** as pastas:
   - ✅ Caixa de entrada
   - ✅ Spam / Lixo eletrônico
   - ✅ Promoções
   - ✅ Social

3. Procure por:
   - Remetente: `noreply@mail.app.supabase.io`
   - Assunto: Deve conter "Spartan" ou "Confirm"

4. **Tempo de espera:** 30 segundos a 2 minutos

---

## 📋 PASSO 4: Analisar Resultado

### ✅ CENÁRIO 1: Email chegou!

**Parabéns! O sistema está funcionando!**

Agora você pode:
1. Clicar no link do email
2. Implementar a página de confirmação
3. Usar o sistema normalmente

---

### ❌ CENÁRIO 2: Email NÃO chegou

Execute o diagnóstico:

#### A) Verificar logs do Supabase

1. Vá em **Logs** → **Auth Logs**
2. Procure por eventos recentes
3. Verifique se há erros

#### B) Executar diagnóstico SQL

No SQL Editor, execute:

```sql
-- Ver últimos usuários criados
SELECT 
  email,
  email_confirmed_at,
  created_at,
  CASE 
    WHEN email_confirmed_at IS NULL THEN '❌ Não confirmado'
    ELSE '✅ Confirmado'
  END as status
FROM auth.users
ORDER BY created_at DESC
LIMIT 5;
```

#### C) Verificar configuração novamente

Volte ao **PASSO 1** e confirme que:
- ✅ "Enable email confirmations" está ON
- ✅ Template "Confirm signup" está configurado
- ✅ Redirect URLs estão corretas

---

### ⚠️ CENÁRIO 3: Erro ao executar

Se aparecer erro como:
```
User already registered
```

**Solução:**
```sql
DELETE FROM auth.users WHERE email = 'seu-email@gmail.com';
DELETE FROM public.users WHERE email = 'seu-email@gmail.com';
```

Depois tente novamente.

---

## 📋 PASSO 5: Reportar Resultado

Depois de executar os testes, me informe:

### ✅ Checklist de Informações:

```
☐ Configuração do Supabase:
  ☐ Enable email confirmations: ON/OFF?
  ☐ Template configurado: SIM/NÃO?
  ☐ Redirect URLs: Configuradas?

☐ Teste de Email:
  ☐ Código executou sem erro: SIM/NÃO?
  ☐ Email chegou: SIM/NÃO?
  ☐ Onde chegou: Inbox/Spam/Não chegou?
  ☐ Tempo de espera: _____ segundos

☐ Logs do Supabase:
  ☐ Há erros nos logs: SIM/NÃO?
  ☐ Qual erro: ___________

☐ SQL Diagnóstico:
  ☐ Usuário foi criado no auth.users: SIM/NÃO?
  ☐ Email está confirmado: SIM/NÃO?
```

---

## 💡 DICAS IMPORTANTES

### Se o email demorar muito:

1. **Aguarde até 2 minutos** (pode haver delay)
2. **Verifique SPAM** (90% dos casos está aqui!)
3. **Tente outro provedor** (Gmail → Outlook ou vice-versa)

### Se continuar não funcionando:

1. **Verifique se o Supabase está em modo gratuito**
   - Projetos gratuitos têm limite de emails
   - Veja em: Settings → Billing

2. **Verifique se o projeto está pausado**
   - Projetos inativos são pausados após 7 dias
   - Veja em: Settings → General

3. **Tente criar um novo projeto de teste**
   - Às vezes a configuração fica corrompida
   - Crie novo projeto e teste lá

---

## 🎯 RESUMO

1. ✅ Configure o Supabase corretamente
2. ✅ Limpe usuários de teste
3. ✅ Execute o teste de email
4. ✅ Verifique seu email (inclusive SPAM!)
5. ✅ Reporte o resultado

**Com essas informações, podemos identificar o problema exato!**
