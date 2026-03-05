// lib/services/mercado_pago_service.dart

class MercadoPagoService {
  /// Gera um QR Code PIX chamando a Edge Function do Supabase (A ser implementado).
  /// Por enquanto, retorna uma URL Mock.
  static Future<String> createPixCheckout({
    required String planName,
    required String userId,
    required String userEmail,
    required double amount,
  }) async {
    // ⚠️ TODO: Implementar chamada à Edge Function real do Mercado Pago

    print(
        "MOCK MERCADO PAGO: Gerando PIX para $userEmail (Valor: R\$ $amount)");
    await Future.delayed(const Duration(seconds: 2));

    // Na implementação real, retornaremos o código 'Copia e Cola' ou uma rota pra exibir o QR Code
    // Para teste de UI, simulamos um sucesso:
    return "https://mercado-pago-mock.com/pix-check-out";
  }

  /// Cancela a recorrência do Mercado Pago (A ser implementado).
  static Future<Map<String, dynamic>> cancelRecurrence({
    required String userId,
  }) async {
    // Mercado Pago PIX geralmente não tem recorrência automática como o cartão,
    // mas se usarmos assinaturas do MP, precisaremos implementar aqui.
    return {
      'success': true,
      'message': 'Assinatura cancelada no Mercado Pago (Mock)',
    };
  }
}
