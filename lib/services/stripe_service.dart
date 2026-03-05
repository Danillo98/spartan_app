import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/stripe_config.dart';

class StripeService {
  /// Cria uma sessão de checkout no Stripe chamando a Edge Function do Supabase.
  static Future<String> createCheckoutSession({
    required String priceId,
    required String userId,
    required String userEmail,
    Map<String, String>? metadata,
  }) async {
    const functionName = 'create-checkout-session';

    if (StripeConfig.checkoutFunctionUrl.isEmpty) {
      print(
          "⚠️ MOCK: Simulando criação de checkout para $userEmail (Plano: $priceId)");
      await Future.delayed(const Duration(seconds: 2));
      return "https://checkout.stripe.com/test-mock-url";
    }

    try {
      String origin = 'https://spartanapp.com.br';
      try {
        origin = Uri.base.origin;
      } catch (e) {
        // Fallback
      }

      final bodyData = {
        'priceId': priceId,
        'userId': userId,
        'userEmail': userEmail,
        'userMetadata': metadata,
        'origin': origin,
      };

      final response = await Supabase.instance.client.functions.invoke(
        functionName,
        body: bodyData,
      );

      final data = response.data;
      if (data != null && data['url'] != null) {
        return data['url'];
      } else {
        throw Exception('Resposta inválida do Stripe: $data');
      }
    } catch (e) {
      throw Exception('Erro de conexão com Stripe: $e');
    }
  }

  /// Cancela a assinatura do usuário no Stripe
  static Future<Map<String, dynamic>> cancelSubscription({
    required String userId,
  }) async {
    const functionName = 'cancel-subscription';

    try {
      final response = await Supabase.instance.client.functions.invoke(
        functionName,
        body: {
          'userId': userId,
          'confirmCancellation': true,
        },
      );

      final data = response.data;

      if (data != null && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Assinatura cancelada com sucesso',
          'deletionDate': data['deletionDate'],
        };
      } else {
        throw Exception(data?['error'] ?? 'Erro no cancelamento do Stripe');
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao cancelar assinatura no Stripe: $e',
      };
    }
  }
}
