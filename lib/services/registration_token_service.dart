import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Serviço para criptografar e descriptografar dados de cadastro
/// Os dados são enviados no link do email, sem armazenar no banco
class RegistrationTokenService {
  // Chave secreta - MUDE ISSO PARA UMA CHAVE ÚNICA DO SEU APP!
  // Em produção, use uma variável de ambiente
  // IMPORTANTE: Use \$ para escapar o símbolo $ em strings Dart
  static const String _secretKey = 'Sp4rt4n-App-2026-S3cr3tK3y-XyZ123-Secure';

  /// Cria token com dados do cadastro
  /// Retorna: token criptografado + timestamp de expiração
  static Map<String, dynamic> createToken({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String cnpj,
    required String cpf,
    required String address,
    String? birthDate,
    Map<String, dynamic>? extraData, // Dados adicionais opcionais
    int expirationHours = 24,
  }) {
    // Timestamp de expiração (24 horas)
    final expiresAt = DateTime.now().add(Duration(hours: expirationHours));

    // Dados para criptografar
    final data = {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'cnpj': cnpj,
      'cpf': cpf,
      'address': address,
      if (birthDate != null) 'birthDate': birthDate,
      if (extraData != null) ...extraData, // Mesclar dados extras
      'exp': expiresAt.millisecondsSinceEpoch,
    };

    // Converter para JSON
    final jsonData = jsonEncode(data);

    // Criptografar (Base64 + HMAC para verificação)
    final bytes = utf8.encode(jsonData);
    final base64Data = base64Url.encode(bytes);

    // Criar assinatura HMAC para evitar adulteração
    final hmacBytes = utf8.encode('$base64Data.$_secretKey');
    final hmacDigest = sha256.convert(hmacBytes);
    final signature = base64Url.encode(hmacDigest.bytes);

    // Token final: dados.assinatura
    final token = '$base64Data.$signature';

    return {
      'token': token,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  /// Valida e decodifica token
  /// Retorna dados se válido, null se inválido/expirado
  static Map<String, dynamic>? validateToken(String token) {
    try {
      // Separar dados e assinatura
      final parts = token.split('.');
      if (parts.length != 2) return null;

      final base64Data = parts[0];
      final signature = parts[1];

      // Verificar assinatura
      final hmacBytes = utf8.encode('$base64Data.$_secretKey');
      final hmacDigest = sha256.convert(hmacBytes);
      final expectedSignature = base64Url.encode(hmacDigest.bytes);

      if (signature != expectedSignature) {
        // Token adulterado!
        return null;
      }

      // Decodificar dados
      final bytes = base64Url.decode(base64Data);
      final jsonData = utf8.decode(bytes);
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      // Verificar expiração
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(data['exp'] as int);
      if (DateTime.now().isAfter(expiresAt)) {
        // Token expirado!
        return null;
      }

      // Remover timestamp de expiração dos dados retornados
      data.remove('exp');

      return data;
    } catch (e) {
      return null;
    }
  }

  /// Gera URL de confirmação com token
  static String generateConfirmationUrl(String token) {
    // URL do seu app/site que vai processar a confirmação
    // Pode ser um deep link ou URL web
    return 'https://seu-dominio.com/confirm?token=$token';

    // Ou deep link para o app:
    // return 'io.supabase.spartanapp://confirm?token=$token';
  }
}
