import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'audit_log_service.dart';
import 'rate_limit_service.dart';
import 'secure_storage_service.dart';
import '../models/user_role.dart';
import '../utils/validators.dart';

/// Serviço de autenticação com segurança avançada
/// Integra rate limiting, audit logs e armazenamento seguro
class AuthServiceSecure {
  static final SupabaseClient _client = SupabaseService.client;

  // ============================================
  // REGISTRO DE ADMINISTRADOR
  // ============================================
  static Future<Map<String, dynamic>> registerAdmin({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String cnpj,
    required String cpf,
    required String address,
  }) async {
    try {
      // 1. VALIDAÇÕES DE SEGURANÇA

      // Validar nome
      if (!Validators.isValidName(name)) {
        return {
          'success': false,
          'message': 'Nome inválido. Use apenas letras e espaços',
        };
      }

      // Validar email
      if (!Validators.isValidEmail(email)) {
        return {
          'success': false,
          'message': 'Email inválido',
        };
      }

      // Validar senha forte
      final passwordValidation = Validators.validatePassword(password);
      if (!passwordValidation['isValid']) {
        final errors = passwordValidation['errors'] as List<String>;
        return {
          'success': false,
          'message': errors.join('\n'),
        };
      }

      // Validar telefone
      if (!Validators.isValidPhone(phone)) {
        return {
          'success': false,
          'message': 'Telefone inválido. Use formato: (XX) XXXXX-XXXX',
        };
      }

      // Validar CPF
      if (!Validators.isValidCPF(cpf)) {
        return {
          'success': false,
          'message': 'CPF inválido',
        };
      }

      // Validar CNPJ
      if (!Validators.isValidCNPJ(cnpj)) {
        return {
          'success': false,
          'message': 'CNPJ inválido',
        };
      }

      // Validar endereço
      if (!Validators.isValidAddress(address)) {
        return {
          'success': false,
          'message': 'Endereço inválido. Mínimo 10 caracteres',
        };
      }

      // Sanitizar inputs
      final sanitizedName = Validators.sanitizeString(name);
      final sanitizedAddress = Validators.sanitizeString(address);

      // 2. CRIAR USUÁRIO NO SUPABASE AUTH
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Erro ao criar usuário');
      }

      // 3. INSERIR DADOS NA TABELA USERS
      final userData = await _client
          .from('users')
          .insert({
            'id': authResponse.user!.id,
            'name': sanitizedName,
            'email': email,
            'phone': phone,
            'password_hash': 'managed_by_supabase_auth',
            'role': 'admin',
            'cnpj': cnpj,
            'cpf': cpf,
            'address': sanitizedAddress,
          })
          .select()
          .single();

      // 4. REGISTRAR LOG DE AUDITORIA
      await AuditLogService.logUserCreated(
        adminUserId: authResponse.user!.id,
        newUserId: authResponse.user!.id,
        newUserEmail: email,
        newUserRole: 'admin',
      );

      return {
        'success': true,
        'user': userData,
        'message': 'Administrador cadastrado com sucesso!',
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.message),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao cadastrar: ${e.toString()}',
      };
    }
  }

  // ============================================
  // LOGIN COM PROTEÇÃO CONTRA FORÇA BRUTA
  // ============================================
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    try {
      // 1. VALIDAÇÕES BÁSICAS
      if (!Validators.isValidEmail(email)) {
        return {
          'success': false,
          'message': 'Email inválido',
        };
      }

      // 2. VERIFICAR RATE LIMITING
      if (!RateLimitService.canAttemptLogin(email)) {
        final blockedTime = RateLimitService.getLoginBlockedTime(email);

        // Registrar tentativa bloqueada
        await AuditLogService.logLoginFailed(
          email: email,
          reason: 'Bloqueado por excesso de tentativas',
        );

        return {
          'success': false,
          'message':
              'Muitas tentativas de login. Tente novamente em $blockedTime minutos',
        };
      }

      // 3. TENTAR FAZER LOGIN
      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Credenciais inválidas');
      }

      // 4. BUSCAR DADOS DO USUÁRIO
      final userData = await _client
          .from('users')
          .select()
          .eq('id', authResponse.user!.id)
          .single();

      // 5. VERIFICAR ROLE
      final userRole = _stringToRole(userData['role']);
      if (userRole != expectedRole) {
        await _client.auth.signOut();

        // Registrar acesso não autorizado
        await AuditLogService.logUnauthorizedAccess(
          userId: authResponse.user!.id,
          resource: 'login',
          action: 'Tentativa de login com role incorreto',
        );

        RateLimitService.recordLoginAttempt(email);

        return {
          'success': false,
          'message': 'Este usuário não tem permissão para acessar este perfil',
        };
      }

      // 6. LOGIN BEM-SUCEDIDO

      // Resetar tentativas de login
      RateLimitService.resetLoginAttempts(email);

      // Salvar sessão de forma segura
      await SecureStorageService.saveSessionData(
        accessToken: authResponse.session!.accessToken,
        userId: authResponse.user!.id,
        userRole: _roleToString(userRole),
        userEmail: email,
        refreshToken: authResponse.session!.refreshToken,
      );

      // Registrar log de auditoria
      await AuditLogService.logLogin(
        userId: authResponse.user!.id,
        email: email,
      );

      return {
        'success': true,
        'user': userData,
        'role': userRole,
        'message': 'Login realizado com sucesso!',
      };
    } on AuthException catch (e) {
      // Registrar tentativa falhada
      RateLimitService.recordLoginAttempt(email);

      await AuditLogService.logLoginFailed(
        email: email,
        reason: e.message,
      );

      final remainingAttempts =
          RateLimitService.getRemainingLoginAttempts(email);
      String message = _getAuthErrorMessage(e.message);

      if (remainingAttempts > 0 && remainingAttempts <= 3) {
        message += '\n\nTentativas restantes: $remainingAttempts';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      RateLimitService.recordLoginAttempt(email);

      await AuditLogService.logLoginFailed(
        email: email,
        reason: e.toString(),
      );

      return {
        'success': false,
        'message': 'Erro ao fazer login: ${e.toString()}',
      };
    }
  }

  // ============================================
  // LOGOUT SEGURO
  // ============================================
  static Future<void> signOut() async {
    final userId = await SecureStorageService.getUserId();

    // Registrar logout
    if (userId != null) {
      await AuditLogService.logLogout(userId: userId);
    }

    // Fazer logout no Supabase
    await _client.auth.signOut();

    // Limpar dados locais
    await SecureStorageService.clearSessionData();
  }

  // ============================================
  // VERIFICAÇÕES DE SESSÃO
  // ============================================

  /// Verifica se o usuário está autenticado e a sessão é válida
  static Future<bool> isAuthenticated() async {
    // Verifica armazenamento local
    if (!await SecureStorageService.isAuthenticated()) {
      return false;
    }

    // Verifica timeout
    if (await SecureStorageService.isSessionExpired()) {
      await signOut();
      return false;
    }

    // Atualiza última atividade
    await SecureStorageService.updateLastActivity();

    return true;
  }

  /// Obtém o usuário atual
  static User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Obtém dados completos do usuário atual
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final userData =
          await _client.from('users').select().eq('id', user.id).single();
      return userData;
    } catch (e) {
      return null;
    }
  }

  /// Obtém role do usuário atual
  static Future<UserRole?> getCurrentUserRole() async {
    final userData = await getCurrentUserData();
    if (userData == null) return null;
    return _stringToRole(userData['role']);
  }

  // ============================================
  // RESET DE SENHA
  // ============================================
  static Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      // Validar email
      if (!Validators.isValidEmail(email)) {
        return {
          'success': false,
          'message': 'Email inválido',
        };
      }

      // Verificar rate limiting
      if (!RateLimitService.canAttemptPasswordReset(email)) {
        return {
          'success': false,
          'message': 'Muitas tentativas. Aguarde alguns minutos',
        };
      }

      await _client.auth.resetPasswordForEmail(email);

      // Registrar tentativa
      RateLimitService.recordPasswordResetAttempt(email);

      // Registrar log
      await AuditLogService.logPasswordReset(email: email);

      return {
        'success': true,
        'message': 'Email de recuperação enviado com sucesso!',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao enviar email de recuperação',
      };
    }
  }

  // ============================================
  // STREAM DE AUTENTICAÇÃO
  // ============================================
  static Stream<AuthState> get authStateChanges {
    return _client.auth.onAuthStateChange;
  }

  // ============================================
  // FUNÇÕES AUXILIARES
  // ============================================

  static UserRole _stringToRole(String roleString) {
    switch (roleString) {
      case 'admin':
        return UserRole.admin;
      case 'nutritionist':
        return UserRole.nutritionist;
      case 'trainer':
        return UserRole.trainer;
      case 'student':
        return UserRole.student;
      default:
        throw Exception('Role inválido: $roleString');
    }
  }

  static String _roleToString(UserRole role) {
    return role.toString().split('.').last;
  }

  static String _getAuthErrorMessage(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Email ou senha incorretos';
    } else if (error.contains('Email not confirmed')) {
      return 'Por favor, confirme seu email antes de fazer login';
    } else if (error.contains('User already registered')) {
      return 'Este email já está cadastrado';
    } else if (error.contains('Password should be at least 6 characters')) {
      return 'A senha deve ter no mínimo 6 caracteres';
    } else if (error.contains('only request this after') ||
        error.contains('security purposes')) {
      return 'Por favor, aguarde alguns segundos antes de tentar novamente';
    } else {
      return 'Erro de autenticação: $error';
    }
  }
}
