import '../config/payment_config.dart';
import '../config/stripe_config.dart';
import 'stripe_service.dart';
import 'mercado_pago_service.dart';

class PaymentService {
  /// Cria uma sessão de checkout chamando o provedor ativo.
  /// Retorna a URL para redirecionamento ou código PIX.
  static Future<String> createCheckoutSession({
    required String priceId,
    required String userId,
    required String userEmail,
    Map<String, String>? metadata,
  }) async {
    if (PaymentConfig.activeProvider == PaymentProvider.mercadoPago) {
      // Para o Mercado Pago PIX, podemos usar o nome do plano se o priceId não for numérico
      // ou converter/buscar o valor correspondente ao priceId.
      // Por simplicidade inicial, passamos os dados básicos.
      return MercadoPagoService.createPixCheckout(
        planName: metadata?['plano_selecionado'] ?? 'Plano Spartan',
        userId: userId,
        userEmail: userEmail,
        amount: _getAmountByPriceId(priceId),
      );
    } else {
      // Provedor padrão: Stripe
      return StripeService.createCheckoutSession(
        priceId: priceId,
        userId: userId,
        userEmail: userEmail,
        metadata: metadata,
      );
    }
  }

  /// Cancela a assinatura no provedor ativo
  static Future<Map<String, dynamic>> cancelSubscription({
    required String userId,
  }) async {
    if (PaymentConfig.activeProvider == PaymentProvider.mercadoPago) {
      return MercadoPagoService.cancelRecurrence(userId: userId);
    } else {
      return StripeService.cancelSubscription(userId: userId);
    }
  }

  /// Helper para pegar o ID do plano (Stripe) baseado no nome selecionado
  static String getPriceIdByName(String planName) {
    switch (planName.toLowerCase()) {
      case 'prata':
        return StripeConfig.pricePrata;
      case 'ouro':
        return StripeConfig.priceOuro;
      case 'platina':
        return StripeConfig.pricePlatina;
      case 'diamante':
        return StripeConfig.priceDiamante;
      default:
        throw Exception('Plano desconhecido: $planName');
    }
  }

  /// Helper interno para converter PriceID em valor numérico (usado pelo Mercado Pago)
  static double _getAmountByPriceId(String priceId) {
    if (priceId == StripeConfig.pricePrata) return 129.90;
    if (priceId == StripeConfig.priceOuro) return 239.90;
    if (priceId == StripeConfig.pricePlatina) return 349.90;
    if (priceId == StripeConfig.priceDiamante) return 459.90;
    return 0.0;
  }
}
