import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/firebase_options.dart';

class NotificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Inicializa o Firebase e configura notificações (Tokens e Permissões)
  static Future<void> init() async {
    try {
      // 1. Inicializar Firebase App
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("🔥 Firebase Initialized");

      // 2. Pedir Permissão
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 Permissão: ${settings.authorizationStatus}');

      // 3. Pegar Token FCM e Salvar no Supabase
      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint("🎟️ FCM Token obtido: $token");
        await _saveTokenToSupabase(token);
      }

      // 4. Ouvir atualização de Token
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint("🔄 FCM Token atualizado: $newToken");
        _saveTokenToSupabase(newToken);
      });

      // 5. Configurar ouvintes de Foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print(
            '📩 Mensagem em Foreground recebida: ${message.notification?.title}');
        // Aqui você pode mostrar um SnackBar ou Dialog se quiser
      });
    } catch (e) {
      debugPrint("❌ Erro ao inicializar Firebase Messaging: $e");
    }
  }

  /// Salva o token na tabela user_fcm_tokens
  static Future<void> _saveTokenToSupabase(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('user_fcm_tokens').upsert(
        {
          'user_id': user.id,
          'fcm_token': token,
          'device_type': 'android/web', // Simplificação
          'last_updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id, fcm_token',
      );
      debugPrint("💾 Token salvo no Supabase para user: ${user.id}");
    } catch (e) {
      debugPrint("❌ Erro ao salvar token no Supabase: $e");
    }
  }

  /// Inscreve o usuário no Tópico da Academia ao Logar
  static Future<void> loginUser(String? idAcademia) async {
    // 1. Garantir que o token está salvo (caso o usuario tenha logado agora)
    String? token = await _messaging.getToken();
    if (token != null) await _saveTokenToSupabase(token);

    // 2. Inscrever no tópico da academia
    if (idAcademia != null) {
      final topic = 'academy_${idAcademia.replaceAll('-', '')}';
      await _messaging.subscribeToTopic(topic);
      debugPrint("📢 Inscrito no tópico: $topic");
    }
  }

  /// Remove inscrição ao deslogar
  static Future<void> logoutUser(String? oldIdAcademia) async {
    try {
      if (oldIdAcademia != null) {
        final topic = 'academy_${oldIdAcademia.replaceAll('-', '')}';
        await _messaging.unsubscribeFromTopic(topic);
        debugPrint("🔕 Desinscrito do tópico: $topic");
      }
    } catch (e) {
      debugPrint("❌ Erro ao deslogar notificações: $e");
    }
  }

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
        debugPrint("✅ Push sent successfully via Edge Function");
        return true;
      } else {
        debugPrint(
            "❌ Error sending Push: ${response.status} - ${response.data}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Exception sending Push: $e");
      return false;
    }
  }

  // --- USE CASES ---

  // 1. Treino (Já existe)
  static Future<void> notifyNewWorkout(
      String studentId, String personalName) async {
    await sendPush(
      title: "Novo Treino!",
      content: "Personal $personalName acabou de atualizar seu treino! 💪",
      targetPlayerIds: [studentId],
      data: {"type": "new_workout"},
    );
  }

  // 2. Dieta (Já existe)
  static Future<void> notifyNewDiet(String studentId, String nutriName) async {
    await sendPush(
      title: "Nova Dieta!",
      content: "Seu novo plano alimentar já está disponível. Confira agora! 🍎",
      targetPlayerIds: [studentId],
      data: {"type": "new_diet"},
    );
  }

  // 3. Avisos (Já existe)
  static Future<void> notifyNotice(String title, String authorRole,
      {String? targetStudentId, String? idAcademia}) async {
    if (targetStudentId != null) {
      await sendPush(
        title: "Novo Aviso 📌",
        content: title,
        targetPlayerIds: [targetStudentId],
        data: {"type": "notice"},
      );
    } else if (idAcademia != null) {
      final topic = 'academy_${idAcademia.replaceAll('-', '')}';
      await sendPush(
        title: "Aviso da Academia 📢",
        content: title,
        targetTopic: topic,
        data: {"type": "notice"},
      );
    }
  }

  // 4. Avaliação Física (NOVO)
  static Future<void> notifyNewAssessment(String studentId) async {
    await sendPush(
      title: "Nova Avaliação Física 📏",
      content: "Confira seus novos resultados e evolução no App!",
      targetPlayerIds: [studentId],
      data: {"type": "new_assessment"},
    );
  }

  // 5. Agendamento (NOVO)
  static Future<void> notifyNewAppointment(
      List<String> professionalIds, String studentName, String dateStr) async {
    await sendPush(
      title: "Novo Agendamento 📅",
      content:
          "$studentName agendou um horário dia $dateStr. Confira sua agenda!",
      targetPlayerIds: professionalIds,
      data: {"type": "new_appointment"},
    );
  }

  static Future<void> notifyAppointmentReminder(
      String userId, String timeStr) async {
    await sendPush(
      title: "Lembrete de Agendamento ⏰",
      content: "Você tem um compromisso hoje às $timeStr. Não se atrase!",
      targetPlayerIds: [userId],
      data: {"type": "appointment_reminder"},
    );
  }

  // 6. Financeiro - Aluno (NOVO)
  static Future<void> notifyPaymentDue(String studentId) async {
    await sendPush(
      title: "Mensalidade Vencendo 📅",
      content: "Sua mensalidade vence hoje. Evite bloqueios renovando agora!",
      targetPlayerIds: [studentId],
      data: {"type": "payment_due"},
    );
  }

  static Future<void> notifyPaymentOverdue(String studentId) async {
    await sendPush(
      title: "Mensalidade em Atraso ⚠️",
      content:
          "Consta uma pendência financeira. Regularize para acessar o app.",
      targetPlayerIds: [studentId],
      data: {"type": "payment_overdue"},
    );
  }

  // 7. Financeiro - Admin (NOVO)
  // Notifica o Admin sobre alunos vencidos
  static Future<void> notifyAdminOverdueStudents(
      String adminId, List<String> studentNames) async {
    if (studentNames.isEmpty) return;

    String content;
    if (studentNames.length == 1) {
      content = "O aluno ${studentNames.first} está com a mensalidade VENCIDA!";
    } else {
      content = "No momento existem alunos com as mensalidades VENCIDAS!";
    }

    await sendPush(
      title: "Alerta Financeiro 💰",
      content: content,
      targetPlayerIds: [adminId],
      data: {"type": "admin_financial_alert"},
    );
  }
}
