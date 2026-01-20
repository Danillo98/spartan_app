import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Envia notificação usando Supabase Edge Function (send-push)
  static Future<bool> sendPush({
    required String title,
    required String content,
    List<String>? targetPlayerIds, // User IDs
    String? targetTopic,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'send-push',
        body: {
          'title': title,
          'body': content,
          'userIds': targetPlayerIds,
          'topic': targetTopic,
          'data': data,
        },
      );

      if (response.status == 200) {
        print("✅ Push sent successfully via Edge Function");
        return true;
      } else {
        print("❌ Error sending Push: ${response.status} - ${response.data}");
        return false;
      }
    } catch (e) {
      print("❌ Exception sending Push: $e");
      return false;
    }
  }

  // --- USE CASES ---

  static Future<void> notifyNewWorkout(
      String studentId, String personalName) async {
    await sendPush(
      title: "Novo Treino!",
      content: "Personal $personalName acabou de atualizar seu treino! 💪",
      targetPlayerIds: [studentId],
      data: {"type": "new_workout"},
    );
  }

  static Future<void> notifyNewDiet(String studentId, String nutriName) async {
    await sendPush(
      title: "Nova Dieta!",
      content: "Seu novo plano alimentar já está disponível. Confira agora! 🍎",
      targetPlayerIds: [studentId],
      data: {"type": "new_diet"},
    );
  }

  static Future<void> notifyNotice(String title, String authorRole,
      {String? targetStudentId, String? academyCnpj}) async {
    if (targetStudentId != null) {
      // Specific Student
      await sendPush(
        title: "Novo Aviso 📌",
        content: title,
        targetPlayerIds: [targetStudentId],
        data: {"type": "notice"},
      );
    } else if (academyCnpj != null) {
      // Academy Wide via Topic
      final topic =
          'academy_${academyCnpj.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
      await sendPush(
        title: "Aviso da Academia 📢",
        content: title,
        targetTopic: topic,
        data: {"type": "notice"},
      );
    }
  }

  // Init method to keep main.dart happy, though actual logic is now server-side or handled by OS
  static Future<void> init() async {
    print("NotificationService Initialized (Logic moved to Edge Functions)");
    // Here we strictly handle token saving logic if needed client side,
    // but the actual sending is now properly delegated.
  }
}
