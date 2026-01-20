import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../config/onesignal_config.dart';

class NotificationService {
  static const String _baseUrl = "https://onesignal.com/api/v1/notifications";

  // Inicializa o OneSignal no App
  static Future<void> init() async {
    // Removemos a verificação de null/empty para não quebrar o init se o user ainda não configurou,
    // mas logamos um aviso.
    if (OneSignalConfig.oneSignalAppId == "YOUR_ONESIGNAL_APP_ID") {
      print("⚠️ OneSignal App ID não configurado em onesignal_config.dart");
      return;
    }

    // Verbose logging set to help debug issues, remove before releasing your app.
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    OneSignal.initialize(OneSignalConfig.oneSignalAppId);

    // Prompt for Push Notification Permissions
    OneSignal.Notifications.requestPermission(true);
  }

  // Identifica o usuário no OneSignal para segmentação
  static Future<void> loginUser(
      String userId, String role, String academyCnpj) async {
    if (OneSignalConfig.oneSignalAppId == "YOUR_ONESIGNAL_APP_ID") return;

    OneSignal.login(userId);
    OneSignal.User.addTags({
      "role": role,
      "academy_cnpj": academyCnpj,
    });
  }

  static Future<void> logoutUser() async {
    if (OneSignalConfig.oneSignalAppId == "YOUR_ONESIGNAL_APP_ID") return;
    OneSignal.logout();
  }

  // Enviar Push (Via REST API)
  // Usado para disparar notificações de um usuário para outro
  static Future<bool> sendPush({
    required String title,
    required String content,
    List<String>? targetPlayerIds, // IDs externos (nossos user_ids)
    List<String>? targetSegments, // Ex: ["All", "Active Users"]
    Map<String, dynamic>? data,
  }) async {
    if (OneSignalConfig.oneSignalRestApiKey == "YOUR_ONESIGNAL_REST_API_KEY") {
      print("⚠️ OneSignal API Key não configurada. Push não enviado.");
      return false;
    }

    try {
      final headers = {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": "Basic ${OneSignalConfig.oneSignalRestApiKey}",
      };

      final body = {
        "app_id": OneSignalConfig.oneSignalAppId,
        "headings": {"en": title, "pt": title},
        "contents": {"en": content, "pt": content},
        if (targetPlayerIds != null)
          "include_aliases": {"external_id": targetPlayerIds},
        if (targetSegments != null) "included_segments": targetSegments,
        if (data != null) "data": data,
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print("✅ Push enviado com sucesso: $title");
        return true;
      } else {
        print("❌ Erro ao enviar Push: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Exceção ao enviar Push: $e");
      return false;
    }
  }

  // Casos de Uso Específicos

  // 1. Novo Treino (Personal -> Aluno)
  static Future<void> notifyNewWorkout(
      String studentId, String personalName) async {
    await sendPush(
      title: "Novo Treino!",
      content: "Personal $personalName acabou de atualizar seu treino! 💪",
      targetPlayerIds: [studentId],
      data: {"type": "new_workout"},
    );
  }

  // 2. Nova Dieta (Nutri -> Aluno)
  static Future<void> notifyNewDiet(String studentId, String nutriName) async {
    await sendPush(
      title: "Nova Dieta!",
      content: "Seu novo plano alimentar já está disponível. Confira agora! 🍎",
      targetPlayerIds: [studentId],
      data: {"type": "new_diet"},
    );
  }

  // 3. Aviso Mural (Personal/Nutri -> Aluno Específico ou Todos da Academia se Admin)
  static Future<void> notifyNotice(
      String title, String authorRole, // 'Admin', 'Personal', 'Nutricionista'
      {String? targetStudentId,
      String? academyCnpj}) async {
    if (targetStudentId != null) {
      // Aviso Específico
      await sendPush(
        title: "Novo Aviso 📌",
        content: title, // Título do aviso vira conteúdo da push
        targetPlayerIds: [targetStudentId],
        data: {"type": "notice"},
      );
    } else if (academyCnpj != null) {
      // Aviso Geral da Academia (Segmentado por Tag)
      // Requer que tenhamos criado Segmentos no OneSignal ou filtro por Tag
      // Vamos usar filtro por Tag via API

      if (OneSignalConfig.oneSignalRestApiKey == "YOUR_ONESIGNAL_REST_API_KEY")
        return;

      final headers = {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": "Basic ${OneSignalConfig.oneSignalRestApiKey}",
      };

      final body = {
        "app_id": OneSignalConfig.oneSignalAppId,
        "headings": {
          "en": "Aviso da Academia 📢",
          "pt": "Aviso da Academia 📢"
        },
        "contents": {"en": title, "pt": title},
        "filters": [
          {
            "field": "tag",
            "key": "academy_cnpj",
            "relation": "=",
            "value": academyCnpj
          }
        ],
        "data": {"type": "notice"},
      };

      await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: jsonEncode(body),
      );
    }
  }

  // 4. Agendar Pagamento (Financeiro)
  static Future<void> schedulePaymentReminder(
      String studentId, int dueDay) async {
    // Lógica complexa de agendamento requeira calcular data exata.
    // Para simplificar neste MVP, não implementaremos agendamento remoto via API aqui
    // pois requer gerenciamento de IDs de notificação para cancelar se pagar.
    // Recomendação: Usar Local Notifications ou Jobs no Backend.
    print("⚠️ Agendamento de notificação de pagamento requer backend job.");
  }
}
