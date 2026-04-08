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
      throw Exception('Erro ao conectar com Mercado Pago (PIX): $e');
    }
  }

  /// Links de checkout dos Planos fixos criados no Mercado Pago.
  /// São URLs públicas geradas pela plataforma — não precisam de API call.
  static final Map<String, String> _planCheckoutUrls = {
    'prata':    'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=e1267c1b6f98490cb8c3f4e8216ef66a',
    'ouro':     'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=619a262122fe4e209685136c833bfec0',
    'platina':  'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=44b11288134d40aeaa699dac9362a6c3',
    'diamante': 'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=cad3033195b34b07958a90ee4ed93fc3',
  };

  /// Cria uma Assinatura via Cartão de Crédito no Mercado Pago.
  /// Retorna o link de checkout do plano fixo (sem chamada de rede interna).
  static Future<Map<String, dynamic>> createCardSubscription({
    required String planName,
    required String userId,
    required String userEmail,
    required double amount,
  }) async {
    final planKey = planName.toLowerCase().trim();
    final baseUrl = _planCheckoutUrls[planKey];

    if (baseUrl == null) {
      throw Exception('Plano inválido: "$planName"');
    }

    // Vincula userId via external_reference para rastreamento no webhook.
    // NÃO pré-preenchemos payer_email pois o email do app pode ser o mesmo
    // da conta vendedora no MP, o que causa rejeição automática.
    final checkoutUrl = '$baseUrl&external_reference=${Uri.encodeComponent(userId)}';

    return {
      'success': true,
      'init_point': checkoutUrl,
    };
  }

  /// Cancela a recorrência - cancela a assinatura de cartão via API do Mercado Pago
  static Future<Map<String, dynamic>> cancelRecurrence({
    required String userId,
    String? subscriptionId,
  }) async {
    try {
       final response = await Supabase.instance.client.functions.invoke(
         'cancelar-assinatura-cartao',
         body: {
           'userId': userId,
           'subscriptionId': subscriptionId,
         },
       );

       final data = response.data;
       if (data != null && data['success'] == true) {
         return {
           'success': true,
           'message': 'Plano cancelado com sucesso no Mercado Pago.',
         };
       } else {
         throw Exception(data?['error'] ?? 'Erro ao cancelar Assinatura no MP');
       }
    } catch (e) {
      // Se der erro, avisa
      throw Exception('Erro ao processar cancelamento (MP): $e');
    }
  }
}
