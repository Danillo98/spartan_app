import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Serviço de auditoria e logs de segurança
/// Registra todas as ações importantes para rastreabilidade
class AuditLogService {
  static final SupabaseClient _client = SupabaseService.client;

  // ============================================
  // TIPOS DE EVENTOS
  // ============================================
  static const String eventLogin = 'login';
  static const String eventLoginFailed = 'login_failed';
  static const String eventLogout = 'logout';
  static const String eventUserCreated = 'user_created';
  static const String eventUserUpdated = 'user_updated';
  static const String eventUserDeleted = 'user_deleted';
  static const String eventPasswordChanged = 'password_changed';
  static const String eventPasswordReset = 'password_reset';
  static const String eventUnauthorizedAccess = 'unauthorized_access';
  static const String eventDataExport = 'data_export';
  static const String eventDataImport = 'data_import';
  static const String eventPermissionChanged = 'permission_changed';

  // ============================================
  // NÍVEIS DE SEVERIDADE
  // ============================================
  static const String severityInfo = 'info';
  static const String severityWarning = 'warning';
  static const String severityError = 'error';
  static const String severityCritical = 'critical';

  // ============================================
  // REGISTRO DE LOGS
  // ============================================

  /// Registra um evento de auditoria
  static Future<void> log({
    required String eventType,
    required String severity,
    String? userId,
    String? targetUserId,
    String? description,
    Map<String, dynamic>? metadata,
    String? ipAddress,
  }) async {
    try {
      await _client.from('audit_logs').insert({
        'event_type': eventType,
        'severity': severity,
        'user_id': userId,
        'target_user_id': targetUserId,
        'description': description,
        'metadata': metadata,
        'ip_address': ipAddress,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Não falhar a operação principal se o log falhar
      print('Erro ao registrar log de auditoria: $e');
    }
  }

  // ============================================
  // LOGS DE AUTENTICAÇÃO
  // ============================================

  /// Registra login bem-sucedido
  static Future<void> logLogin({
    required String userId,
    required String email,
    String? ipAddress,
  }) async {
    await log(
      eventType: eventLogin,
      severity: severityInfo,
      userId: userId,
      description: 'Login realizado com sucesso',
      metadata: {'email': email},
      ipAddress: ipAddress,
    );
  }

  /// Registra tentativa de login falhada
  static Future<void> logLoginFailed({
    required String email,
    required String reason,
    String? ipAddress,
  }) async {
    await log(
      eventType: eventLoginFailed,
      severity: severityWarning,
      description: 'Tentativa de login falhada: $reason',
      metadata: {'email': email, 'reason': reason},
      ipAddress: ipAddress,
    );
  }

  /// Registra logout
  static Future<void> logLogout({
    required String userId,
    String? ipAddress,
  }) async {
    await log(
      eventType: eventLogout,
      severity: severityInfo,
      userId: userId,
      description: 'Logout realizado',
      ipAddress: ipAddress,
    );
  }

  // ============================================
  // LOGS DE GERENCIAMENTO DE USUÁRIOS
  // ============================================

  /// Registra criação de usuário
  static Future<void> logUserCreated({
    required String adminUserId,
    required String newUserId,
    required String newUserEmail,
    required String newUserRole,
    String? ipAddress,
  }) async {
    await log(
      eventType: eventUserCreated,
      severity: severityInfo,
      userId: adminUserId,
      targetUserId: newUserId,
      description: 'Novo usuário criado',
      metadata: {
        'email': newUserEmail,
        'role': newUserRole,
      },
      ipAddress: ipAddress,
    );
  }

  /// Registra atualização de usuário
  static Future<void> logUserUpdated({
    required String adminUserId,
    required String targetUserId,
    required Map<String, dynamic> changes,
    String? ipAddress,
  }) async {
    await log(
      eventType: eventUserUpdated,
      severity: severityInfo,
      userId: adminUserId,
      targetUserId: targetUserId,
      description: 'Dados de usuário atualizados',
      metadata: {'changes': changes},
      ipAddress: ipAddress,
    );
  }

  /// Registra exclusão de usuário
  static Future<void> logUserDeleted({
    required String adminUserId,
    required String deletedUserId,
    required String deletedUserEmail,
    String? ipAddress,
  }) async {
    await log(
      eventType: eventUserDeleted,
      severity: severityWarning,
      userId: adminUserId,
      targetUserId: deletedUserId,
      description: 'Usuário excluído',
      metadata: {'email': deletedUserEmail},
      ipAddress: ipAddress,
    );
  }

  // ============================================
  // LOGS DE SEGURANÇA
  // ============================================

  /// Registra mudança de senha
  static Future<void> logPasswordChanged({
    required String userId,
    String? ipAddress,
  }) async {
    await log(
      eventType: eventPasswordChanged,
      severity: severityInfo,
      userId: userId,
      description: 'Senha alterada',
      ipAddress: ipAddress,
    );
  }

  /// Registra reset de senha
  static Future<void> logPasswordReset({
    required String email,
    String? ipAddress,
  }) async {
    await log(
      eventType: eventPasswordReset,
      severity: severityInfo,
      description: 'Solicitação de reset de senha',
      metadata: {'email': email},
      ipAddress: ipAddress,
    );
  }

  /// Registra tentativa de acesso não autorizado
  static Future<void> logUnauthorizedAccess({
    String? userId,
    required String resource,
    required String action,
    String? ipAddress,
  }) async {
    await log(
      eventType: eventUnauthorizedAccess,
      severity: severityCritical,
      userId: userId,
      description: 'Tentativa de acesso não autorizado',
      metadata: {
        'resource': resource,
        'action': action,
      },
      ipAddress: ipAddress,
    );
  }

  /// Registra mudança de permissões
  static Future<void> logPermissionChanged({
    required String adminUserId,
    required String targetUserId,
    required String oldRole,
    required String newRole,
    String? ipAddress,
  }) async {
    await log(
      eventType: eventPermissionChanged,
      severity: severityWarning,
      userId: adminUserId,
      targetUserId: targetUserId,
      description: 'Permissões de usuário alteradas',
      metadata: {
        'old_role': oldRole,
        'new_role': newRole,
      },
      ipAddress: ipAddress,
    );
  }

  // ============================================
  // CONSULTA DE LOGS
  // ============================================

  /// Busca logs por usuário
  static Future<List<Map<String, dynamic>>> getLogsByUser({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .from('audit_logs')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erro ao buscar logs: $e');
      return [];
    }
  }

  /// Busca logs por tipo de evento
  static Future<List<Map<String, dynamic>>> getLogsByEventType({
    required String eventType,
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .from('audit_logs')
          .select()
          .eq('event_type', eventType)
          .order('timestamp', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erro ao buscar logs: $e');
      return [];
    }
  }

  /// Busca logs por severidade
  static Future<List<Map<String, dynamic>>> getLogsBySeverity({
    required String severity,
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .from('audit_logs')
          .select()
          .eq('severity', severity)
          .order('timestamp', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erro ao buscar logs: $e');
      return [];
    }
  }

  /// Busca logs em um período
  static Future<List<Map<String, dynamic>>> getLogsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  }) async {
    try {
      final response = await _client
          .from('audit_logs')
          .select()
          .gte('timestamp', startDate.toIso8601String())
          .lte('timestamp', endDate.toIso8601String())
          .order('timestamp', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erro ao buscar logs: $e');
      return [];
    }
  }

  /// Busca logs críticos recentes
  static Future<List<Map<String, dynamic>>> getCriticalLogs({
    int limit = 20,
  }) async {
    return await getLogsBySeverity(
      severity: severityCritical,
      limit: limit,
    );
  }
}
