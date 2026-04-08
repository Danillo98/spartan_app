import '../config/payment_config.dart';
import '../config/stripe_config.dart';
import 'stripe_service.dart';
import 'mercado_pago_service.dart';

class PaymentService {
  /// Retorna true se o provedor ativo é o Mercado Pago (PIX).
  /// Use isso na UI para decidir qual fluxo de checkout abrir.
  static bool get isPixProvider =>
      PaymentConfig.activeProvider == PaymentProvider.mercadoPago;

  /// Cria uma sessão de checkout STRIPE. Retorna a URL de redirecionamento.
  /// Use apenas quando isPixProvider == false.
  static Future<String> createCheckoutSession({
    required String priceId,
    required String userId,
    required String userEmail,
    Map<String, String>? metadata,
  }) async {
    return StripeService.createCheckoutSession(
      priceId: priceId,
      userId: userId,
      userEmail: userEmail,
      metadata: metadata,
    );
  }

  /// Gera um PIX via Mercado Pago. Retorna um Map com qrCode, qrCodeBase64, paymentId.
  /// Use apenas quando isPixProvider == true.
  static Future<Map<String, dynamic>> createPixData({
    required String planName,
    required String userId,
    required String userEmail,
    required double amount,
  }) async {
    return MercadoPagoService.createPixCheckout(
      planName: planName,
      userId: userId,
      userEmail: userEmail,
      amount: amount,
    );
  }

  /// Gera uma assinatura via Cartão no Mercado Pago. Retorna um Map com init_point e preapproval_id.
  static Future<Map<String, dynamic>> createCardSubscription({
    required String planName,
    required String userId,
    required String userEmail,
    required double amount,
  }) async {
    return MercadoPagoService.createCardSubscription(
      planName: planName,
      userId: userId,
      userEmail: userEmail,
      amount: amount,
    );
  }

  /// Cancela a assinatura no provedor ativo
  static Future<Map<String, dynamic>> cancelSubscription({
    required String userId,
    String? subscriptionId,
  }) async {
    if (PaymentConfig.activeProvider == PaymentProvider.mercadoPago) {
      return MercadoPagoService.cancelRecurrence(
        userId: userId, 
        subscriptionId: subscriptionId
      );
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

  /// Retorna o valor em R$ de um plano pelo nome (prata, ouro, platina, diamante)
  static double getAmountByPlanName(String planName) {
    switch (planName.toLowerCase()) {
      case 'prata':
        return 129.90;
      case 'ouro':
        return 239.90;
      case 'platina':
        return 349.90;
      case 'diamante':
        return 459.90;
      default:
        return 0.0;
    }
  }
}
