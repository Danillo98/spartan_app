/// Serviço de Rate Limiting para proteção contra ataques de força bruta
/// Limita o número de tentativas de ações sensíveis
class RateLimitService {
  // Armazena tentativas por chave (email, userId, etc)
  static final Map<String, List<DateTime>> _attempts = {};

  // Armazena bloqueios temporários
  static final Map<String, DateTime> _blockedUntil = {};

  // ============================================
  // CONFIGURAÇÕES
  // ============================================

  /// Número máximo de tentativas permitidas
  static const int maxAttempts = 5;

  /// Janela de tempo para contar tentativas (em minutos)
  static const int timeWindowMinutes = 15;

  /// Tempo de bloqueio após exceder tentativas (em minutos)
  static const int blockDurationMinutes = 30;

  // ============================================
  // VERIFICAÇÃO DE RATE LIMIT
  // ============================================

  /// Verifica se uma ação está bloqueada por rate limit
  static bool isBlocked(String key) {
    _cleanupOldData();

    // Verifica se está em bloqueio temporário
    if (_blockedUntil.containsKey(key)) {
      final blockedUntil = _blockedUntil[key]!;
      if (DateTime.now().isBefore(blockedUntil)) {
        return true;
      } else {
        // Bloqueio expirou, remove
        _blockedUntil.remove(key);
        _attempts.remove(key);
        return false;
      }
    }

    return false;
  }

  /// Registra uma tentativa
  static void recordAttempt(String key) {
    _cleanupOldData();

    if (!_attempts.containsKey(key)) {
      _attempts[key] = [];
    }

    _attempts[key]!.add(DateTime.now());

    // Verifica se excedeu o limite
    if (_attempts[key]!.length >= maxAttempts) {
      _blockKey(key);
    }
  }

  /// Obtém o número de tentativas restantes
  static int getRemainingAttempts(String key) {
    _cleanupOldData();

    if (isBlocked(key)) return 0;

    final attempts = _attempts[key]?.length ?? 0;
    return maxAttempts - attempts;
  }

  /// Obtém o tempo restante de bloqueio (em minutos)
  static int? getBlockedTimeRemaining(String key) {
    if (!_blockedUntil.containsKey(key)) return null;

    final blockedUntil = _blockedUntil[key]!;
    final now = DateTime.now();

    if (now.isAfter(blockedUntil)) {
      _blockedUntil.remove(key);
      return null;
    }

    final difference = blockedUntil.difference(now);
    return difference.inMinutes + 1;
  }

  /// Reseta as tentativas de uma chave (após sucesso)
  static void resetAttempts(String key) {
    _attempts.remove(key);
    _blockedUntil.remove(key);
  }

  /// Bloqueia uma chave temporariamente
  static void _blockKey(String key) {
    final blockUntil = DateTime.now().add(
      Duration(minutes: blockDurationMinutes),
    );
    _blockedUntil[key] = blockUntil;
  }

  /// Remove dados antigos (fora da janela de tempo)
  static void _cleanupOldData() {
    final now = DateTime.now();
    final cutoffTime = now.subtract(Duration(minutes: timeWindowMinutes));

    // Limpa tentativas antigas
    _attempts.forEach((key, attempts) {
      attempts.removeWhere((time) => time.isBefore(cutoffTime));
    });

    // Remove chaves vazias
    _attempts.removeWhere((key, attempts) => attempts.isEmpty);

    // Limpa bloqueios expirados
    _blockedUntil.removeWhere((key, blockedUntil) => now.isAfter(blockedUntil));
  }

  // ============================================
  // MÉTODOS ESPECÍFICOS
  // ============================================

  /// Verifica rate limit para login
  static bool canAttemptLogin(String email) {
    return !isBlocked('login_$email');
  }

  /// Registra tentativa de login
  static void recordLoginAttempt(String email) {
    recordAttempt('login_$email');
  }

  /// Reseta tentativas de login após sucesso
  static void resetLoginAttempts(String email) {
    resetAttempts('login_$email');
  }

  /// Obtém tentativas restantes de login
  static int getRemainingLoginAttempts(String email) {
    return getRemainingAttempts('login_$email');
  }

  /// Obtém tempo de bloqueio de login
  static int? getLoginBlockedTime(String email) {
    return getBlockedTimeRemaining('login_$email');
  }

  /// Verifica rate limit para reset de senha
  static bool canAttemptPasswordReset(String email) {
    return !isBlocked('password_reset_$email');
  }

  /// Registra tentativa de reset de senha
  static void recordPasswordResetAttempt(String email) {
    recordAttempt('password_reset_$email');
  }

  /// Verifica rate limit para criação de usuário
  static bool canCreateUser(String adminId) {
    return !isBlocked('create_user_$adminId');
  }

  /// Registra tentativa de criação de usuário
  static void recordCreateUserAttempt(String adminId) {
    recordAttempt('create_user_$adminId');
  }

  /// Verifica rate limit para API em geral
  static bool canMakeApiCall(String userId, String endpoint) {
    return !isBlocked('api_${userId}_$endpoint');
  }

  /// Registra chamada de API
  static void recordApiCall(String userId, String endpoint) {
    recordAttempt('api_${userId}_$endpoint');
  }

  // ============================================
  // ADMINISTRAÇÃO
  // ============================================

  /// Limpa todos os dados de rate limiting
  static void clearAll() {
    _attempts.clear();
    _blockedUntil.clear();
  }

  /// Desbloqueia uma chave específica (uso administrativo)
  static void unblock(String key) {
    _attempts.remove(key);
    _blockedUntil.remove(key);
  }

  /// Obtém estatísticas de rate limiting
  static Map<String, dynamic> getStatistics() {
    _cleanupOldData();

    return {
      'total_tracked_keys': _attempts.length,
      'total_blocked_keys': _blockedUntil.length,
      'blocked_keys': _blockedUntil.keys.toList(),
      'active_attempts': _attempts.map(
        (key, attempts) => MapEntry(key, attempts.length),
      ),
    };
  }
}
