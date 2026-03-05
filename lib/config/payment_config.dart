enum PaymentProvider { stripe, mercadoPago }

class PaymentConfig {
  /// Define qual provedor de pagamento está ativo no sistema.
  /// Mude para [PaymentProvider.stripe] para voltar ao sistema original instantaneamente.
  static const PaymentProvider activeProvider = PaymentProvider.mercadoPago;

  // Chave pública do Mercado Pago (pode estar no app - não é secreta)
  static const String mpPublicKey =
      'APP_USR-165ac6d8-d4a3-41b1-96a1-717adb1e0ce6';
}
