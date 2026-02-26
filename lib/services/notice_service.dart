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
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (admin != null) return admin['id'];

    // 2. Aluno
    final student = await _client
        .from('users_alunos')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (student != null) return student['id_academia'];

    // 3. Nutri
    final nutri = await _client
        .from('users_nutricionista')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (nutri != null) return nutri['id_academia'];

    // 4. Personal
    final trainer = await _client
        .from('users_personal')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (trainer != null) return trainer['id_academia'];

    throw Exception('Academia não encontrada para o usuário');
  }

  // Helper para detectar Role do usuário atual
  static Future<String> _getCurrentUserRoleString(String userId) async {
    final admin =
        await _client.from('users_adm').select().eq('id', userId).maybeSingle();
    if (admin != null) return 'admin';

    final student = await _client
        .from('users_alunos')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (student != null) return 'student';

    final nutri = await _client
        .from('users_nutricionista')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (nutri != null) return 'nutritionist';

    final trainer = await _client
        .from('users_personal')
        .select()
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
      final myId = user.id;

      print('🔍 [NOTICES] Buscando avisos para: role=$myRole, id=$myId');

      // Buscar TODOS os avisos ativos da academia
      final response = await _client
          .from('notices')
          .select()
          .eq('id_academia', idAcademia)
          .lte('start_at', now)
          .gte('end_at', now)
          .order('created_at', ascending: false);

      final rawNotices = List<Map<String, dynamic>>.from(response);
      print('📋 [NOTICES] Total bruto: ${rawNotices.length}');

      // **FILTRO RIGOROSO DE PRIVACIDADE**
      final notices = rawNotices.where((notice) {
        final targetRole = notice['target_role'] ?? 'all';
        var targetUserIds = notice['target_user_ids'];

        // Converter target_user_ids para List<String> se necessário
        List<String> userIdsList = [];
        if (targetUserIds != null) {
          if (targetUserIds is List) {
            userIdsList = List<String>.from(
                targetUserIds.map((e) => e.toString().trim()));
          } else if (targetUserIds is String && targetUserIds.isNotEmpty) {
            // Pode vir como "{uuid1,uuid2}" do Postgres
            userIdsList = targetUserIds
                .replaceAll('{', '')
                .replaceAll('}', '')
                .replaceAll('[', '')
                .replaceAll(']', '')
                .replaceAll('"', '')
                .replaceAll("'", "")
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }

        print(
            '🔍 Aviso "${notice['title']}": role=$targetRole, users=$userIdsList');

        // **REGRA 1: Admin vê tudo (opcional, depende da sua regra de negócio)**
        // Se você NÃO quer que admin veja avisos privados de outros, comente esta linha
        // if (myRole == 'admin') return true;

        // **REGRA 2: Se tem target_user_ids preenchido, SOMENTE esses usuários podem ver**
        if (userIdsList.isNotEmpty) {
          final canSee = userIdsList.contains(myId);
          print('  -> Aviso ESPECÍFICO. Eu posso ver? $canSee');
          return canSee;
        }

        // **REGRA 3: Se target_user_ids está vazio/null, verificar target_role**
        // Se target_role == 'all', todos podem ver
        if (targetRole == 'all') {
          print('  -> Aviso PÚBLICO (all)');
          return true;
        }

        // Se target_role == meu role, posso ver
        if (targetRole == myRole) {
          print('  -> Aviso para meu ROLE ($myRole)');
          return true;
        }

        // Caso contrário, não posso ver
        print('  -> Aviso BLOQUEADO (role diferente)');
        return false;
      }).toList();

      print('✅ [NOTICES] Total filtrado: ${notices.length}');

      await _injectPaymentWarning(user.id, notices, idAcademia);

      return notices;
    } catch (e) {
      print('❌ Erro ao buscar avisos ativos: $e');
      return [];
    }
  }

  static Future<void> _injectPaymentWarning(String userId,
      List<Map<String, dynamic>> notices, String idAcademia) async {
    try {
      final student = await _client
          .from('users_alunos')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (student == null) return;

      final dueDay = student['payment_due_day'] as int?;
      if (dueDay == null) return;

      final now = DateTime.now();
      final diff = dueDay - now.day;

      if (diff >= 0 && diff <= 3) {
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);

        final payment = await _client
            .from('financial_transactions')
            .select()
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

  // --- MÉTODO SIMPLES DE REFRESH (SEM REALTIME) ---
  // Chame este método ao fazer login ou ao abrir opções do dashboard
  static Future<List<Map<String, dynamic>>> refreshNotices() async {
    return await getActiveNotices();
  }
}
