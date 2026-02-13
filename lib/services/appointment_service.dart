import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'supabase_service.dart';
import 'user_service.dart';
import 'notification_service.dart'; // Import NotificationService
import '../models/user_role.dart';

class AppointmentService {
  static final SupabaseClient _client = SupabaseService.client;

  // Obter ID da academia atual
  static Future<String> _getAcademyId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');
    final userId = user.id;

    // Tentar como Admin
    final admin = await _client
        .from('users_adm')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    if (admin != null) return admin['id'];

    // Tentar como Nutricionista
    final nutri = await _client
        .from('users_nutricionista')
        .select('id_academia')
        .eq('id', userId)
        .maybeSingle();
    if (nutri != null && nutri['id_academia'] != null) {
      return nutri['id_academia'];
    }

    // Tentar como Personal
    final personal = await _client
        .from('users_personal')
        .select('id_academia')
        .eq('id', userId)
        .maybeSingle();
    if (personal != null && personal['id_academia'] != null) {
      return personal['id_academia'];
    }

    throw Exception('Academia não encontrada para o usuário atual.');
  }

  // Buscar lista de profissionais disponíveis (Nutris e Personais)
  static Future<List<Map<String, dynamic>>> getAvailableProfessionals() async {
    try {
      final nutris = await UserService.getUsersByRole(UserRole.nutritionist);
      final trainers = await UserService.getUsersByRole(UserRole.trainer);

      // Combinar e adicionar campo de tipo "clean"
      final cleanNutris = nutris
          .map((u) => {
                ...u,
                'type_label': 'Nutricionista',
                'type_code': 'nutritionist'
              })
          .toList();

      final cleanTrainers = trainers
          .map((u) =>
              {...u, 'type_label': 'Personal Trainer', 'type_code': 'trainer'})
          .toList();

      return [...cleanNutris, ...cleanTrainers];
    } catch (e) {
      print('Erro ao buscar profissionais: $e');
      return [];
    }
  }

  // Criar Agendamento
  static Future<Map<String, dynamic>> createAppointment({
    String? studentId,
    String? visitorName,
    String? visitorPhone,
    required List<String> professionalIds,
    required DateTime scheduledAt,
  }) async {
    try {
      final academyId = await _getAcademyId();

      if (studentId == null && (visitorName == null || visitorName.isEmpty)) {
        throw Exception('É necessário informar um aluno ou nome do visitante.');
      }

      final data = {
        'id_academia': academyId,
        'student_id': studentId,
        'visitor_name': visitorName,
        'visitor_phone': visitorPhone,
        'professional_ids': professionalIds,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': 'scheduled',
      };

      await _client.from('appointments').insert(data);

      // --- CRITICAL: NOTIFICATION ---
      try {
        String studentName = visitorName ?? 'Visitante';
        // If studentId is present, try to fetch name (optional, for better UX)
        if (studentId != null) {
          final studentData = await _client
              .from('users_alunos')
              .select('nome')
              .eq('id', studentId)
              .maybeSingle();
          if (studentData != null) {
            studentName = studentData['nome'];
          }
        }

        final formattedDate = DateFormat('dd/MM HH:mm').format(scheduledAt);

        await NotificationService.notifyNewAppointment(
          professionalIds,
          studentName,
          formattedDate,
        );
      } catch (e) {
        print('Erro ao enviar notificação de agendamento: $e');
      }
      // ------------------------------

      return {'success': true, 'message': 'Agendamento realizado com sucesso!'};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao agendar: ${e.toString()}'};
    }
  }

  // Buscar Agendamentos
  static Future<List<Map<String, dynamic>>> getAppointments({
    String?
        statusFilter, // 'scheduled' (Aguardando), 'completed' (Concluída), ou null/all
  }) async {
    try {
      final academyId = await _getAcademyId();

      // Construção da query: Filtros primeiro, Ordem por último
      var query = _client
          .from('appointments')
          .select('*, users_alunos(nome, telefone)')
          .eq('id_academia', academyId);

      if (statusFilter == 'scheduled') {
        query = query.eq('status', 'scheduled');
      } else if (statusFilter == 'completed') {
        query = query.eq('status', 'completed');
      } else if (statusFilter == 'cancelled') {
        query = query.eq('status', 'cancelled');
      }

      final response = await query.order('scheduled_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        final map = item as Map<String, dynamic>;
        // Normalizar nome do aluno se existir
        String? studentName;
        String? studentPhone;

        if (map['users_alunos'] != null) {
          studentName = map['users_alunos']['nome'];
          studentPhone = map['users_alunos']['telefone'];
        }

        return {
          ...map,
          'display_name': studentName ?? map['visitor_name'] ?? 'Desconhecido',
          'display_phone': studentPhone ?? map['visitor_phone'],
        };
      }).toList();
    } catch (e) {
      print('Erro ao buscar agendamentos: $e');
      return [];
    }
  }

  // Buscar Agendamentos DO PROFISSIONAL (Meu Agendamento)
  static Future<List<Map<String, dynamic>>> getMyAppointments() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        print('⚠️ getMyAppointments: Usuário não autenticado.');
        return [];
      }

      print('🔎 Buscando agendamentos para o profissional: ${user.id}');

      // Filtro robusto para JSONB Array no Postgrest
      // Usamos 'cs' (contains) passando o array como string JSON
      final response = await _client
          .from('appointments')
          .select('*, users_alunos(nome, telefone)')
          .filter('professional_ids', 'cs', '["${user.id}"]')
          .eq('status', 'scheduled')
          .order('scheduled_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      print('✅ Encontrados ${data.length} agendamentos para mim.');

      return data.map((item) {
        final map = item as Map<String, dynamic>;
        String? studentName;
        if (map['users_alunos'] != null) {
          studentName = map['users_alunos']['nome'];
        }
        return {
          ...map,
          'display_name': studentName ?? map['visitor_name'] ?? 'Visitante',
        };
      }).toList();
    } catch (e) {
      print('❌ Erro ao buscar meus agendamentos: $e');
      return [];
    }
  }

  // Atualizar Status (Rápido)
  static Future<void> updateStatus(String id, String newStatus) async {
    await _client
        .from('appointments')
        .update({'status': newStatus}).eq('id', id);
  }

  // Deletar Agendamento
  static Future<void> deleteAppointment(String id) async {
    await _client.from('appointments').delete().eq('id', id);
  }

  // Editar Agendamento Completo
  static Future<void> updateAppointment({
    required String id,
    String? studentId,
    String? visitorName,
    String? visitorPhone,
    required List<String> professionalIds,
    required DateTime scheduledAt,
    String? status, // Novo parametro
  }) async {
    try {
      if (studentId == null && (visitorName == null || visitorName.isEmpty)) {
        throw Exception('É necessário informar um aluno ou nome do visitante.');
      }

      final data = {
        'student_id': studentId,
        'visitor_name': visitorName,
        'visitor_phone': visitorPhone,
        'professional_ids': professionalIds,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      };

      if (status != null) {
        data['status'] = status;
      }

      await _client.from('appointments').update(data).eq('id', id);
    } catch (e) {
      throw Exception('Erro ao atualizar: $e');
    }
  }
}
