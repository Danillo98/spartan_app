import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class NoticeService {
  static final SupabaseClient _client = SupabaseService.client;

  // Obter ID da Academia (Auxiliar)
  static Future<String> _getAcademyId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    // 1. Admin
    final admin = await _client
        .from('users_adm')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (admin != null) return admin['id'];

    // 2. Aluno
    final student = await _client
        .from('users_alunos')
        .select('id_academia')
        .eq('id', user.id)
        .maybeSingle();
    if (student != null) return student['id_academia'];

    // 3. Nutri
    final nutri = await _client
        .from('users_nutricionista')
        .select('id_academia')
        .eq('id', user.id)
        .maybeSingle();
    if (nutri != null) return nutri['id_academia'];

    // 4. Personal
    final trainer = await _client
        .from('users_personal')
        .select('id_academia')
        .eq('id', user.id)
        .maybeSingle();
    if (trainer != null) return trainer['id_academia'];

    throw Exception('Academia não encontrada para o usuário');
  }

  // Helper para detectar Role do usuário atual
  static Future<String> _getCurrentUserRoleString(String userId) async {
    final admin = await _client
        .from('users_adm')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    if (admin != null) return 'admin';

    final student = await _client
        .from('users_alunos')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    if (student != null) return 'student';

    final nutri = await _client
        .from('users_nutricionista')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    if (nutri != null) return 'nutritionist';

    final trainer = await _client
        .from('users_personal')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    if (trainer != null) return 'trainer';

    return 'unknown';
  }

  // --- CRUD GERAL ---

  static Future<List<Map<String, dynamic>>> getNotices() async {
    final idAcademia = await _getAcademyId();
    final response = await _client
        .from('notices')
        .select()
        .eq('id_academia', idAcademia)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Método unificado de criação
  static Future<void> createNotice({
    required String title,
    required String description,
    required DateTime startAt,
    required DateTime endAt,

    // Parâmetros de Segmentação
    String targetRole = 'all',
    String? targetUserId, // Depreciado (mantido para compat)
    List<String>? targetUserIds, // NOVO: Lista de IDs

    // Retrocompatibilidade
    String? targetStudentId,
    String authorLabel = 'Gestão da Academia',
  }) async {
    final idAcademia = await _getAcademyId();

    // Unificar IDs em uma lista
    List<String> finalIds = [];
    if (targetUserIds != null) finalIds.addAll(targetUserIds);
    if (targetUserId != null && !finalIds.contains(targetUserId))
      finalIds.add(targetUserId);
    if (targetStudentId != null && !finalIds.contains(targetStudentId)) {
      finalIds.add(targetStudentId);
    }

    // Only set to student if we have specific student IDs, otherwise keep as is (could be 'all')
    // But if sending to specific IDs, usually implies 'student' role in this app context.
    if (finalIds.isNotEmpty && targetRole == 'all') {
      targetRole = 'student';
    }

    await _client.from('notices').insert({
      'id_academia': idAcademia,
      'title': title,
      'description': description,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'target_role': targetRole,
      'target_user_ids': finalIds, // Salva como JSONB array
      // 'target_user_id': targetUserId, // Não salvamos mais singular se tivermos array?
      // Idealmente, se o script 589 rodou, só usamos target_user_ids.
      // Mas se o sistema tiver código legado lendo user_id, podemos duplicar (só para o primeiro).
      // Vamos assumir migração total.
      'author_label': authorLabel,
      'created_by': _client.auth.currentUser?.id,
    });
  }

  static Future<List<Map<String, dynamic>>> getMyNotices() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('notices')
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erro ao buscar meus avisos: $e');
      return [];
    }
  }

  static Future<void> updateNotice({
    required String id,
    required String title,
    required String description,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    await _client.from('notices').update({
      'title': title,
      'description': description,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> deleteNotice(String id) async {
    await _client.from('notices').delete().eq('id', id);
  }

  // --- PUBLICO (Quadro de Avisos) ---

  static Future<List<Map<String, dynamic>>> getActiveNotices() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final idAcademia = await _getAcademyId();
      final now = DateTime.now().toIso8601String();
      final myRole = await _getCurrentUserRoleString(user.id);

      // Query Base
      var query = _client
          .from('notices')
          .select()
          .eq('id_academia', idAcademia)
          .lte('start_at', now)
          .gte('end_at', now);

      if (myRole == 'admin') {
        // Admin vê tudo
      } else {
        // Users normais
        query = query.filter('target_role', 'in', '("all","$myRole")');

        // RLS do banco (script 589) já cuida de esconder avisos
        // onde target_user_ids (array) NÃO contem meu ID
        // E também cuida se target_user_ids for null/vazio (todos).
        // Portanto, não precisamos duplicar essa lógica no client query,
        // exceto talvez para performance/filtragem extra.
      }

      final response = await query.order('created_at', ascending: false);
      final rawNotices = List<Map<String, dynamic>>.from(response);

      // Client-side Filter (Backup for RLS)
      final myId = user.id;
      final notices = rawNotices.where((notice) {
        var targetIds = notice['target_user_ids'];

        // Handle JSON being returned as String
        if (targetIds is String) {
          try {
            if (targetIds.startsWith('[') && targetIds.endsWith(']')) {
              targetIds = targetIds
                  .substring(1, targetIds.length - 1)
                  .split(',')
                  .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ""))
                  .where((e) => e.isNotEmpty)
                  .toList();
            }
          } catch (_) {}
        }

        if (targetIds != null && targetIds is List && targetIds.isNotEmpty) {
          // Ensure we compare strings
          return targetIds.map((e) => e.toString().trim()).contains(myId);
        }

        return true;
      }).toList();

      await _injectPaymentWarning(user.id, notices, idAcademia);

      return notices;
    } catch (e) {
      print('Erro ao buscar avisos ativos: $e');
      return [];
    }
  }

  static Future<void> _injectPaymentWarning(String userId,
      List<Map<String, dynamic>> notices, String idAcademia) async {
    try {
      final student = await _client
          .from('users_alunos')
          .select('payment_due')
          .eq('id', userId)
          .maybeSingle();

      if (student == null) return;

      final dueDay = student['payment_due'] as int?;
      if (dueDay == null) return;

      final now = DateTime.now();
      final diff = dueDay - now.day;

      if (diff >= 0 && diff <= 3) {
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);

        final payment = await _client
            .from('financial_transactions')
            .select('id')
            .eq('id_academia', idAcademia)
            .eq('related_user_id', userId)
            .eq('type', 'income')
            .gte('transaction_date', startOfMonth.toIso8601String())
            .lte('transaction_date', endOfMonth.toIso8601String())
            .maybeSingle();

        if (payment == null) {
          final warningNotice = {
            'id': 'sys_payment_warning_${now.millisecondsSinceEpoch}',
            'title': 'ATENÇÃO',
            'description': 'Sua mensalidade está próxima do vencimento!',
            'author_label': 'Mensagem automática de Spartan App',
            'start_at': now.toIso8601String(),
            'end_at': now.add(const Duration(days: 1)).toIso8601String(),
            'created_at': now.toIso8601String(),
            'id_academia': idAcademia,
            'target_role': 'student',
            'author_role': 'system'
          };
          notices.insert(0, warningNotice);
        }
      }
    } catch (e) {
      print('Erro ao injetar aviso de pagamento: $e');
    }
  }

  // --- REALTIME STREAM ---

  static Stream<List<Map<String, dynamic>>> getActiveNoticesStream() {
    return Stream.fromFuture(Future.wait([
      _getAcademyId(),
      _client.auth.currentUser != null
          ? _getCurrentUserRoleString(_client.auth.currentUser!.id)
          : Future.value('student'),
    ])).asyncExpand((results) {
      final String idAcademia = results[0] as String;
      final String myRole = results[1] as String;
      final String? myId = _client.auth.currentUser?.id;

      return _client
          .from('notices')
          .stream(primaryKey: ['id'])
          .eq('id_academia', idAcademia)
          .order('created_at', ascending: false)
          .map((notices) {
            if (myId == null) return [];

            return notices.where((notice) {
              // 1. Verificar se está no período
              final startAt = DateTime.parse(notice['start_at']);
              final endAt = DateTime.parse(notice['end_at']);
              final nowDt = DateTime.now();

              if (nowDt.isBefore(startAt) || nowDt.isAfter(endAt)) return false;

              // 2. Isolamento por Role
              final targetRole = notice['target_role'] ?? 'all';

              if (myRole != 'admin') {
                if (targetRole != 'all' && targetRole != myRole) return false;

                // 3. Isolamento por Usuário Específico (array target_user_ids)
                var targetIds = notice['target_user_ids'];
                if (targetIds != null) {
                  // Converter string de array do Postgres para lista do Dart se necessário
                  List<String> idList = [];
                  if (targetIds is List) {
                    idList = List<String>.from(targetIds);
                  } else if (targetIds is String) {
                    idList = targetIds
                        .replaceAll('{', '')
                        .replaceAll('}', '')
                        .split(',');
                  }

                  if (idList.isNotEmpty && !idList.contains(myId)) {
                    return false;
                  }
                }
              }

              return true;
            }).toList();
          });
    });
  }
}
