class StripeConfig {
  // Chave Pública
  static const String publishableKey =
      'pk_test_51SwQKJ2LVyCti67LeOdSzjfUPP3prV1Cl4HYAGoTNrFOW5hM2JFZpNddXmki97Nd7RsrxpAA9mKNofynEOvjDoGj00C0yEZQvJ';

  // IDs dos Planos (Produtos)
  static const String pricePrata = 'price_1SwSQU2LVyCti67L89gGsi7t';
  static const String priceOuro = 'price_1SwSRF2LVyCti67LrCh8A6sC';
  static const String pricePlatina = 'price_1SwSRx2LVyCti67LDsm04vM8';

  // URL da Edge Function
  static const String checkoutFunctionUrl =
      'https://waczgosbsrorcibwfayv.supabase.co/functions/v1/create-checkout-session';
}
