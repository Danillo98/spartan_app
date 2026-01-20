import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Serviço para verificação de email com código de 4 dígitos
class EmailVerificationService {
  static final SupabaseClient _client = SupabaseService.client;

  // ============================================
  // ENVIAR CÓDIGO DE VERIFICAÇÃO
  // ============================================

  /// Envia código de 6 dígitos usando sistema nativo do Supabase
  static Future<Map<String, dynamic>> sendVerificationCode({
    required String email,
    String? userName,
  }) async {
    try {
      // Usar sistema OTP nativo do Supabase
      // Envia email automaticamente com token de 6 dígitos
      // 100% GRATUITO e ILIMITADO

      await _client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false, // Não criar usuário automaticamente
      );

      return {
        'success': true,
        'message': 'Código de verificação enviado para $email',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao enviar código: ${e.toString()}',
      };
    }
  }

  // ============================================
  // VERIFICAR CÓDIGO
  // ============================================

  /// Verifica se o código de 6 dígitos está correto
  static Future<Map<String, dynamic>> verifyCode({
    required String email,
    required String code,
  }) async {
    try {
      // Validar formato do código (6 dígitos)
      if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
        return {
          'success': false,
          'message': 'Código deve ter 6 dígitos',
        };
      }

      // Verificar código usando sistema OTP do Supabase
      final response = await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );

      if (response.session != null) {
        // Código válido - fazer logout pois não queremos login ainda
        await _client.auth.signOut();

        return {
          'success': true,
          'message': 'Email verificado com sucesso!',
        };
      } else {
        return {
          'success': false,
          'message': 'Código inválido ou expirado',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Código inválido ou expirado',
      };
    }
  }

  // ============================================
  // VERIFICAR SE EMAIL JÁ FOI VERIFICADO
  // ============================================

  /// Verifica se o email do usuário já foi verificado
  static Future<bool> isEmailVerified(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('email_verified')
          .eq('id', userId)
          .single();

      return response['email_verified'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // REENVIAR CÓDIGO
  // ============================================

  /// Reenvia código de verificação
  static Future<Map<String, dynamic>> resendVerificationCode({
    required String email,
    String? userName,
  }) async {
    return await sendVerificationCode(email: email, userName: userName);
  }

  // ============================================
  // LIMPAR CÓDIGOS EXPIRADOS
  // ============================================

  /// Limpa códigos expirados do banco (chamada administrativa)
  static Future<void> cleanupExpiredCodes() async {
    try {
      await _client.rpc('cleanup_expired_verification_codes');
    } catch (e) {
      print('Erro ao limpar códigos expirados: $e');
    }
  }
}
