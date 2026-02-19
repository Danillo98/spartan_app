class StripeConfig {
  // Chave Pública
  static const String publishableKey =
      'pk_live_51SwQK8RzHrB7utuEJophVkg3iNMjAmk2ajwiymMftEHOuRGIMhPhPHmFsR8SRbTeARwJ7UDwAL51Cu9LkaYNnoUN000uJMEueH';

  // IDs dos Planos (Produtos)
  // IDs dos Planos (Produtos) PRODUCTION
  static const String pricePrata = 'price_1T1W6gRzHrB7utuExu5h1Rsa';
  static const String priceOuro = 'price_1T1W6gRzHrB7utuEZssm3S5j';
  static const String pricePlatina = 'price_1T1W6fRzHrB7utuEisJuDFvn';
  static const String priceDiamante = 'price_1T2QEkRzHrB7utuEwLp9H15c';

  // URL da Edge Function
  static const String checkoutFunctionUrl =
      'https://waczgosbsrorcibwfayv.supabase.co/functions/v1/create-checkout-session';
}
