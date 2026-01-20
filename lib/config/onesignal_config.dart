class OneSignalConfig {
  // Substitua pelos seus valores reais do OneSignal
  // App ID é encontrado em Settings > Keys & IDs no painel do OneSignal
  static const String oneSignalAppId = "YOUR_ONESIGNAL_APP_ID";

  // REST API Key é necessária para enviar notificações via API (Back-End style)
  // Encontrado no mesmo lugar. CUIDADO: Em produção real, requisições com API Key
  // devem ser feitas por um backend seguro (Edge Functions), não direto do app,
  // pois expõe a chave. Para este MVP, faremos direto do app com este aviso.
  static const String oneSignalRestApiKey = "YOUR_ONESIGNAL_REST_API_KEY";
}
