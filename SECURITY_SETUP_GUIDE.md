# 🔐 Guia de Implementação de Segurança - Spartan Gym App

## 📋 O que foi implementado

### ✅ Arquivos Criados

1. **`lib/utils/validators.dart`**
   - Validação de CPF com dígitos verificadores
   - Validação de CNPJ com dígitos verificadores
   - Validação de email (com bloqueio de emails descartáveis)
   - Validação de telefone brasileiro
   - Validação de senha forte (8+ caracteres, maiúsculas, números, especiais)
   - Sanitização de strings (proteção XSS)
   - Validações de nome, endereço, CEP, URLs, datas

2. **`lib/services/secure_storage_service.dart`**
   - Armazenamento criptografado de tokens (AES-256)
   - Gerenciamento de sessão com timeout
   - Proteção de dados sensíveis localmente
   - Verificação de expiração de sessão (30 minutos)

3. **`lib/services/audit_log_service.dart`**
   - Registro de todas as ações importantes
   - Logs de login/logout
   - Logs de criação/edição/exclusão de usuários
   - Logs de acessos não autorizados
   - Consulta de logs por usuário, tipo, severidade

4. **`lib/services/rate_limit_service.dart`**
   - Proteção contra força bruta
   - Limite de 5 tentativas em 15 minutos
   - Bloqueio temporário de 30 minutos
   - Rate limiting para login, reset de senha, APIs

5. **`security_policies.sql`**
   - Tabela de audit_logs
   - Tabela de login_attempts
   - Tabela de active_sessions
   - Funções SQL para validar CPF/CNPJ
   - Políticas RLS avançadas
   - Constraints de validação

6. **`SECURITY_IMPLEMENTATION.md`**
   - Documentação completa de segurança
   - Checklist de implementação
   - Boas práticas

---

## 🚀 Próximos Passos para Implementação

### 1️⃣ Instalar Dependências

**IMPORTANTE**: Você precisa ter o Flutter instalado. Execute:

```bash
flutter pub get
```

Isso instalará:
- `flutter_secure_storage` - Armazenamento criptografado
- `crypto` - Funções de criptografia
- `http` - Requisições HTTP

---

### 2️⃣ Configurar o Supabase

#### A. Executar o Script SQL

1. Acesse seu projeto no [Supabase](https://supabase.com)
2. Vá em **SQL Editor**
3. Abra o arquivo `security_policies.sql`
4. Copie TODO o conteúdo
5. Cole no SQL Editor do Supabase
6. Clique em **Run** (ou pressione Ctrl+Enter)

Isso criará:
- ✅ Tabela `audit_logs` (logs de auditoria)
- ✅ Tabela `login_attempts` (tentativas de login)
- ✅ Tabela `active_sessions` (sessões ativas)
- ✅ Funções de validação de CPF/CNPJ
- ✅ Políticas RLS avançadas

#### B. Verificar se foi criado corretamente

No SQL Editor, execute:

```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('audit_logs', 'login_attempts', 'active_sessions');
```

Deve retornar 3 tabelas.

---

### 3️⃣ Integrar nos Serviços Existentes

#### A. Atualizar `auth_service.dart`

Adicione no início do arquivo:
```dart
import 'audit_log_service.dart';
import 'rate_limit_service.dart';
import 'secure_storage_service.dart';
```

No método `signIn`, adicione:

```dart
// ANTES de tentar fazer login
if (!RateLimitService.canAttemptLogin(email)) {
  final blockedTime = RateLimitService.getLoginBlockedTime(email);
  return {
    'success': false,
    'message': 'Muitas tentativas. Tente novamente em $blockedTime minutos',
  };
}

// APÓS login bem-sucedido
RateLimitService.resetLoginAttempts(email);
await SecureStorageService.saveSessionData(
  accessToken: authResponse.session!.accessToken,
  userId: authResponse.user!.id,
  userRole: _roleToString(userRole),
  userEmail: email,
);
await AuditLogService.logLogin(
  userId: authResponse.user!.id,
  email: email,
);

// APÓS login falhado
RateLimitService.recordLoginAttempt(email);
await AuditLogService.logLoginFailed(
  email: email,
  reason: 'Credenciais inválidas',
);
```

#### B. Atualizar telas de login

Nas telas de login (`login_screen.dart`, `role_login_screen.dart`), adicione validações:

```dart
import '../utils/validators.dart';

// Validar email
if (!Validators.isValidEmail(emailController.text)) {
  // Mostrar erro
  return;
}

// Validar senha
final passwordValidation = Validators.validatePassword(passwordController.text);
if (!passwordValidation['isValid']) {
  // Mostrar erros
  return;
}
```

#### C. Atualizar tela de registro de admin

Em `admin_register_screen.dart`, adicione:

```dart
import '../utils/validators.dart';

// Validar CPF
if (!Validators.isValidCPF(cpfController.text)) {
  // Mostrar erro: "CPF inválido"
  return;
}

// Validar CNPJ
if (!Validators.isValidCNPJ(cnpjController.text)) {
  // Mostrar erro: "CNPJ inválido"
  return;
}

// Validar telefone
if (!Validators.isValidPhone(phoneController.text)) {
  // Mostrar erro: "Telefone inválido"
  return;
}

// Validar senha forte
final passwordValidation = Validators.validatePassword(passwordController.text);
if (!passwordValidation['isValid']) {
  final errors = passwordValidation['errors'] as List<String>;
  // Mostrar todos os erros
  return;
}
```

---

### 4️⃣ Implementar Timeout de Sessão

No `main.dart`, adicione um listener:

```dart
import 'services/secure_storage_service.dart';
import 'services/auth_service.dart';

// No initState do app ou em um wrapper
Timer.periodic(Duration(minutes: 1), (timer) async {
  if (await SecureStorageService.shouldLogoutDueToTimeout()) {
    await AuthService.signOut();
    await SecureStorageService.clearSessionData();
    // Redirecionar para tela de login
  }
});
```

---

### 5️⃣ Proteger Rotas Sensíveis

Crie um middleware de autenticação:

```dart
class AuthGuard {
  static Future<bool> canAccess(UserRole requiredRole) async {
    // Verifica se está autenticado
    if (!await SecureStorageService.isAuthenticated()) {
      return false;
    }

    // Verifica timeout
    if (await SecureStorageService.isSessionExpired()) {
      await AuthService.signOut();
      return false;
    }

    // Atualiza última atividade
    await SecureStorageService.updateLastActivity();

    // Verifica role
    final userRole = await SecureStorageService.getUserRole();
    return userRole == requiredRole.toString().split('.').last;
  }
}
```

---

## 🔒 Configurações de Segurança Adicionais

### Android (`android/app/src/main/AndroidManifest.xml`)

Adicione:
```xml
<application
    android:usesCleartextTraffic="false"
    android:allowBackup="false">
    
    <!-- Proteção contra screenshots em telas sensíveis -->
    <meta-data
        android:name="io.flutter.embedding.android.EnableSoftwareRendering"
        android:value="true" />
</application>
```

### iOS (`ios/Runner/Info.plist`)

Adicione:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

---

## 📊 Monitoramento e Auditoria

### Ver logs de auditoria (Admin)

```dart
// Buscar logs recentes
final logs = await AuditLogService.getLogsByDateRange(
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
);

// Buscar logs críticos
final criticalLogs = await AuditLogService.getCriticalLogs();

// Buscar tentativas de login falhadas
final failedLogins = await AuditLogService.getLogsByEventType(
  eventType: AuditLogService.eventLoginFailed,
);
```

---

## ✅ Checklist de Segurança

### Backend (Supabase)
- [ ] Executar `security_policies.sql` no Supabase
- [ ] Verificar se RLS está habilitado em todas as tabelas
- [ ] Configurar backup automático no Supabase
- [ ] Revisar políticas de acesso

### Frontend (Flutter)
- [ ] Instalar dependências (`flutter pub get`)
- [ ] Integrar validadores em todas as telas de formulário
- [ ] Implementar rate limiting no login
- [ ] Implementar timeout de sessão
- [ ] Adicionar logs de auditoria em ações críticas
- [ ] Testar validações de CPF/CNPJ

### Testes
- [ ] Testar login com credenciais inválidas (deve bloquear após 5 tentativas)
- [ ] Testar CPF/CNPJ inválidos (deve rejeitar)
- [ ] Testar senhas fracas (deve rejeitar)
- [ ] Testar timeout de sessão (deve deslogar após 30 min)
- [ ] Testar acessos não autorizados

---

## 🆘 Resolução de Problemas

### Erro: "flutter_secure_storage not found"
**Solução**: Execute `flutter pub get` no terminal

### Erro: "Table audit_logs does not exist"
**Solução**: Execute o script `security_policies.sql` no Supabase

### Erro: "RLS policy violation"
**Solução**: Verifique se as políticas RLS foram criadas corretamente

### Sessão expira muito rápido
**Solução**: Ajuste o timeout em `SecureStorageService.isSessionExpired(timeoutMinutes: 60)`

---

## 📚 Referências

- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Flutter Security Best Practices](https://flutter.dev/docs/deployment/security)
- [Supabase RLS](https://supabase.com/docs/guides/auth/row-level-security)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)

---

## 🎯 Próximas Melhorias (Opcional)

1. **2FA (Two-Factor Authentication)**
   - Implementar autenticação de dois fatores
   - SMS ou app autenticador

2. **CAPTCHA**
   - Adicionar CAPTCHA após 3 tentativas de login

3. **Biometria**
   - Login com impressão digital/Face ID

4. **Certificate Pinning**
   - Proteção adicional contra MITM

5. **Detecção de Dispositivo Rooteado/Jailbroken**
   - Bloquear app em dispositivos comprometidos

---

**Implementado por**: Antigravity AI
**Data**: 2026-01-15
**Versão**: 1.0
