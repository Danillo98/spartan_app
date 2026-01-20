import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Serviço para armazenamento seguro de dados sensíveis
/// Usa criptografia AES para proteger dados localmente
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ============================================
  // CHAVES DE ARMAZENAMENTO
  // ============================================
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserEmail = 'user_email';
  static const String _keyLastLoginTime = 'last_login_time';
  static const String _keySessionTimeout = 'session_timeout';

  // ============================================
  // TOKENS DE AUTENTICAÇÃO
  // ============================================

  /// Salva o token de acesso de forma segura
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  /// Recupera o token de acesso
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  /// Salva o token de refresh
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Recupera o token de refresh
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  /// Remove todos os tokens (logout)
  static Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  // ============================================
  // DADOS DO USUÁRIO
  // ============================================

  /// Salva o ID do usuário
  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  /// Recupera o ID do usuário
  static Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  /// Salva o role do usuário
  static Future<void> saveUserRole(String role) async {
    await _storage.write(key: _keyUserRole, value: role);
  }

  /// Recupera o role do usuário
  static Future<String?> getUserRole() async {
    return await _storage.read(key: _keyUserRole);
  }

  /// Salva o email do usuário
  static Future<void> saveUserEmail(String email) async {
    await _storage.write(key: _keyUserEmail, value: email);
  }

  /// Recupera o email do usuário
  static Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  // ============================================
  // SESSÃO E TIMEOUT
  // ============================================

  /// Salva o timestamp do último login
  static Future<void> saveLastLoginTime() async {
    final now = DateTime.now().toIso8601String();
    await _storage.write(key: _keyLastLoginTime, value: now);
  }

  /// Recupera o timestamp do último login
  static Future<DateTime?> getLastLoginTime() async {
    final timeString = await _storage.read(key: _keyLastLoginTime);
    if (timeString == null) return null;
    return DateTime.parse(timeString);
  }

  /// Verifica se a sessão expirou (30 minutos de inatividade)
  static Future<bool> isSessionExpired({int timeoutMinutes = 30}) async {
    final lastLogin = await getLastLoginTime();
    if (lastLogin == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastLogin);

    return difference.inMinutes > timeoutMinutes;
  }

  /// Atualiza o timestamp da última atividade
  static Future<void> updateLastActivity() async {
    await saveLastLoginTime();
  }

  // ============================================
  // ARMAZENAMENTO GENÉRICO SEGURO
  // ============================================

  /// Salva um valor string de forma segura
  static Future<void> saveSecureString(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Recupera um valor string seguro
  static Future<String?> getSecureString(String key) async {
    return await _storage.read(key: key);
  }

  /// Salva um objeto JSON de forma segura
  static Future<void> saveSecureJson(
      String key, Map<String, dynamic> json) async {
    final jsonString = jsonEncode(json);
    await _storage.write(key: key, value: jsonString);
  }

  /// Recupera um objeto JSON seguro
  static Future<Map<String, dynamic>?> getSecureJson(String key) async {
    final jsonString = await _storage.read(key: key);
    if (jsonString == null) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Remove um valor específico
  static Future<void> deleteSecureValue(String key) async {
    await _storage.delete(key: key);
  }

  // ============================================
  // LIMPEZA COMPLETA
  // ============================================

  /// Remove TODOS os dados armazenados (usar com cuidado!)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Remove apenas dados de sessão (mantém preferências)
  static Future<void> clearSessionData() async {
    await clearTokens();
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserRole);
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyLastLoginTime);
  }

  // ============================================
  // VERIFICAÇÕES DE SEGURANÇA
  // ============================================

  /// Verifica se o usuário está autenticado
  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    final userId = await getUserId();
    return token != null && userId != null;
  }

  /// Verifica se precisa fazer logout por timeout
  static Future<bool> shouldLogoutDueToTimeout() async {
    if (!await isAuthenticated()) return false;
    return await isSessionExpired();
  }

  // ============================================
  // DADOS COMPLETOS DA SESSÃO
  // ============================================

  /// Salva todos os dados da sessão de uma vez
  static Future<void> saveSessionData({
    required String accessToken,
    required String userId,
    required String userRole,
    required String userEmail,
    String? refreshToken,
  }) async {
    await saveAccessToken(accessToken);
    await saveUserId(userId);
    await saveUserRole(userRole);
    await saveUserEmail(userEmail);
    await saveLastLoginTime();

    if (refreshToken != null) {
      await saveRefreshToken(refreshToken);
    }
  }

  /// Recupera todos os dados da sessão
  static Future<Map<String, dynamic>?> getSessionData() async {
    final accessToken = await getAccessToken();
    final userId = await getUserId();
    final userRole = await getUserRole();
    final userEmail = await getUserEmail();
    final lastLoginTime = await getLastLoginTime();

    if (accessToken == null || userId == null) return null;

    return {
      'accessToken': accessToken,
      'userId': userId,
      'userRole': userRole,
      'userEmail': userEmail,
      'lastLoginTime': lastLoginTime?.toIso8601String(),
    };
  }
}
