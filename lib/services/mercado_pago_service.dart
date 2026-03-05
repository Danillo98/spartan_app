// lib/services/mercado_pago_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class MercadoPagoService {
  /// Gera um pagamento PIX chamando a Edge Function 'gerar-pix' do Supabase.
  /// Retorna um Map com qrCode (copia e cola), qrCodeBase64 (imagem) e paymentId.
  static Future<Map<String, dynamic>> createPixCheckout({
    required String planName,
    required String userId,
    required String userEmail,
    required double amount,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'gerar-pix',
        body: {
          'userId': userId,
          'userEmail': userEmail,
          'planName': planName,
          'amount': amount,
          'externalReference': userId,
        },
      );

      final data = response.data;
      if (data != null && data['success'] == true) {
        return {
          'success': true,
          'paymentId': data['paymentId'],
          'qrCode': data['qrCode'],
          'qrCodeBase64': data['qrCodeBase64'],
          'amount': data['amount'],
          'expiresAt': data['expiresAt'],
        };
      } else {
        throw Exception(data?['error'] ?? 'Erro ao gerar PIX');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com Mercado Pago: $e');
    }
  }

  /// Cancela a recorrência - no PIX manual não há assinatura automática.
  static Future<Map<String, dynamic>> cancelRecurrence({
    required String userId,
  }) async {
    return {
      'success': true,
      'message': 'Plano cancelado. Não haverá nova cobrança no próximo mês.',
    };
  }
}
