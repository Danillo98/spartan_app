enum PaymentProvider { stripe, mercadoPago }

class PaymentConfig {
  /// Define qual provedor de pagamento está ativo no sistema.
  /// Mude para [PaymentProvider.mercadoPago] para ativar o PIX do Mercado Pago.
  /// Mude para [PaymentProvider.stripe] para voltar ao sistema original.
  static const PaymentProvider activeProvider = PaymentProvider.stripe;

  // Configurações do Mercado Pago (Preencher quando tiver as chaves)
  static const String mpPublicKey = 'TEST-YOUR-KEY-HERE';
  static const String mpAccessToken = 'TEST-YOUR-TOKEN-HERE';
}
