import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/stripe_config.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  /// Cria uma sessão de checkout chamando a Edge Function do Supabase.
  /// Retorna a URL para redirecionamento.
  static Future<String> createCheckoutSession({
    required String priceId,
    required String userId,
    required String userEmail,
    Map<String, String>? metadata,
  }) async {
    // URL da sua função (Slug apenas, para usar com o SDK)
    const functionName = 'create-checkout-session';

    if (StripeConfig.checkoutFunctionUrl.isEmpty) {
      // MOCK PARA TESTE DE UI
      print(
          "⚠️ MOCK: Simulando criação de checkout para $userEmail (Plano: $priceId)");
      await Future.delayed(const Duration(seconds: 2));
      return "https://checkout.stripe.com/test-mock-url";
    }

    try {
      // Captura a URL base atual (ex: http://localhost:64007 ou https://spartanapp.com.br)
      // Isso garante que o Stripe redirecione para a mesma porta/domínio que iniciou o fluxo.
      String origin = 'https://spartanapp.com.br';
      try {
        origin = Uri.base.origin;
      } catch (e) {
        // Fallback para mobile ou erro
      }

      print('🚀 Enviando para function ($functionName)...');
      print('📍 ORIGIN detectada: $origin');

      final bodyData = {
        'priceId': priceId,
        'userId': userId,
        'userEmail': userEmail,
        'userMetadata': metadata,
        'origin': origin,
      };

      print('📦 Payload: $bodyData');

      final response = await Supabase.instance.client.functions.invoke(
        functionName,
        body: bodyData,
      );

      // O SDK lança exceção sestatus code não for 2xx? Depende da versão.
      // Geralmente retorna um FunctionResponse.

      final data = response.data;
      if (data != null && data['url'] != null) {
        return data['url'];
      } else {
        throw Exception('Resposta inválida da função: $data');
      }
    } catch (e) {
      throw Exception('Erro de conexão com pagamento: $e');
    }
  }

  /// Helper para pegar o ID do plano baseado no nome selecionado
  static String getPriceIdByName(String planName) {
    switch (planName.toLowerCase()) {
      case 'prata':
        return StripeConfig.pricePrata;
      case 'ouro':
        return StripeConfig.priceOuro;
      case 'platina':
        return StripeConfig.pricePlatina;
      default:
        throw Exception('Plano desconhecido: $planName');
    }
  }
}
