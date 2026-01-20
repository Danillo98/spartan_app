import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class NoticeService {
  static final SupabaseClient _client = SupabaseService.client;

  // Obter CNPJ (Auxiliar) - Similar ao AppointmentService
  static Future<String> _getAcademyCnpj() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    // Tenta buscar em cada tabela para descobrir o CNPJ do usuário atual
    // Otimização: Cachear isso seria ideal, mas por segurança vamos checar

    // 1. Admin
    final admin = await _client
        .from('users_adm')
        .select('cnpj_academia')
        .eq('id', user.id)
        .maybeSingle();
    if (admin != null) return admin['cnpj_academia'];

    // 2. Aluno
    final student = await _client
        .from('users_alunos')
        .select('cnpj_academia')
        .eq('id', user.id)
        .maybeSingle();
    if (student != null) return student['cnpj_academia'];

    // 3. Nutri
    final nutri = await _client
        .from('users_nutricionista')
        .select('cnpj_academia')
        .eq('id', user.id)
        .maybeSingle();
    if (nutri != null) return nutri['cnpj_academia'];

    // 4. Personal
    final trainer = await _client
        .from('users_personal')
        .select('cnpj_academia')
        .eq('id', user.id)
        .maybeSingle();
    if (trainer != null) return trainer['cnpj_academia'];

    throw Exception('Academia não encontrada para o usuário');
  }

  // --- CRUD ADMIN ---

  static Future<List<Map<String, dynamic>>> getNotices() async {
    final cnpj = await _getAcademyCnpj();
    // Lista ordenada por criação (mais recentes primeiro)
    final response = await _client
        .from('notices')
        .select()
        .eq('cnpj_academia', cnpj)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> createNotice({
    required String title,
    required String description,
    required DateTime startAt,
    required DateTime endAt,
    String? targetStudentId,
    String authorLabel = 'Gestão da Academia',
  }) async {
    final cnpj = await _getAcademyCnpj();
    await _client.from('notices').insert({
      'cnpj_academia': cnpj,
      'title': title,
      'description': description,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'target_student_id': targetStudentId,
      'author_label': authorLabel,
      'created_by': _client.auth.currentUser?.id,
    });
  }

  // Busca avisos criados pelo usuário atual
  static Future<List<Map<String, dynamic>>> getMyNotices() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('notices')
          .select(
              '*, users_alunos(nome)') // join para pegar nome do aluno alvo se houver
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

  // --- PUBLICO ---

  // Retorna LISTA de avisos ativos ordenados (Especificos primeiro, depois gerais)
  static Future<List<Map<String, dynamic>>> getActiveNotices() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final cnpj = await _getAcademyCnpj();
      final now = DateTime.now().toIso8601String();

      // Busca avisos ativos da academia
      // O RLS já filtra se o target_student_id é null ou é igual ao ID do user logado
      final response = await _client
          .from('notices')
          .select()
          .eq('cnpj_academia', cnpj)
          .or('target_student_id.is.null,target_student_id.eq.${user.id}')
          .lte('start_at', now) // Começou antes ou agora
          .gte('end_at', now) // Termina depois ou agora
          .order('created_at', ascending: false);

      final notices = List<Map<String, dynamic>>.from(response);

      // --- INJECT SYSTEM WARNINGS ---
      await _injectPaymentWarning(user.id, notices, cnpj);

      return notices;
    } catch (e) {
      print('Erro ao buscar avisos ativos: $e');
      return [];
    }
  }

  // Verifica e injeta aviso de pagamento (Regra de 3 dias)
  static Future<void> _injectPaymentWarning(
      String userId, List<Map<String, dynamic>> notices, String cnpj) async {
    try {
      // 1. Verificar se é aluno e pegar dia de vencimento
      final student = await _client
          .from('users_alunos')
          .select('payment_due_day')
          .eq('id', userId)
          .maybeSingle();

      if (student == null) return; // Não é aluno

      final dueDay = student['payment_due_day'] as int?;
      if (dueDay == null) return; // Sem dia definido

      final now = DateTime.now();

      // Regra: Faltam 3 dias ou menos (inclusive o dia)
      // Range: [DueDate - 3, DueDate]
      // Ex: Vence dia 10. Hoje 7. Diff = 3. Mostra.
      // Ex: Vence dia 10. Hoje 10. Diff = 0. Mostra.
      // Ex: Vence dia 10. Hoje 11. Diff = -1. Não mostra (Vencido/Bloqueado).
      final diff = dueDay - now.day;

      if (diff >= 0 && diff <= 3) {
        // Verificar se JÁ PAGOU neste mês
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);

        final payment = await _client
            .from('financial_transactions')
            .select('id')
            .eq('cnpj_academia', cnpj)
            .eq('related_user_id', userId)
            .eq('type', 'income')
            .gte('transaction_date', startOfMonth.toIso8601String())
            .lte('transaction_date', endOfMonth.toIso8601String())
            .maybeSingle();

        if (payment == null) {
          // NÃO PAGOU -> Adicionar aviso
          final warningNotice = {
            'id': 'sys_payment_warning_${now.millisecondsSinceEpoch}',
            'title': 'ATENÇÃO',
            'description': 'Sua mensalidade está próxima do vencimento!',
            'author_label': 'Mensagem automática de Spartan App',
            'start_at': now.toIso8601String(),
            'end_at': now.add(const Duration(days: 1)).toIso8601String(),
            'created_at': now.toIso8601String(),
            'cnpj_academia': cnpj,
          };

          // Inserir no topo
          notices.insert(0, warningNotice);
        }
      }
    } catch (e) {
      print('Erro ao injetar aviso de pagamento: $e');
    }
  }
}
