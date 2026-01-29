import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'user_service.dart';
import 'notification_service.dart'; // Import Notification
import '../models/user_role.dart';

class FinancialService {
  static final SupabaseClient _client = SupabaseService.client;

  // Obter ID da academia atual (contexto do Admin)
  static Future<String> _getAcademyId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    // Apenas Admin acessa Finanças, então o ID do usuário é o ID da academia
    return user.id;
  }

  // Adicionar Transação
  static Future<void> addTransaction({
    required String description,
    required double amount,
    required String type, // 'income' or 'expense'
    required DateTime date,
    String? category, // 'fixed', 'variable' for expenses
    String? relatedUserId,
    String? relatedUserRole,
    DateTime? dueDate,
  }) async {
    final idAcademia = await _getAcademyId();

    await _client.from('financial_transactions').insert({
      'id_academia': idAcademia, // Use id_academia
      // 'cnpj_academia': cnpj, // REMOVE
      'description': description,
      'amount': amount,
      'type': type,
      'category': category,
      'transaction_date': date.toIso8601String().split('T')[0],
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'related_user_id': relatedUserId,
      'related_user_role': relatedUserRole,
    });
  }

  // Buscar transações (com replicação de fixas)
  static Future<List<Map<String, dynamic>>> getTransactions({
    int? month,
    int? year,
  }) async {
    final idAcademia = await _getAcademyId();
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    // Data inicial e final do mês ALVO
    final startOfMonth = DateTime(targetYear, targetMonth, 1);
    final endOfMonth = DateTime(targetYear, targetMonth + 1, 0);

    // 1. Buscar transações DO MÊS ESPECÍFICO
    final responseCurrent = await _client
        .from('financial_transactions')
        .select()
        .eq('id_academia', idAcademia)
        .gte('transaction_date', startOfMonth.toIso8601String())
        .lte('transaction_date', endOfMonth.toIso8601String())
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false);

    final transactions = List<Map<String, dynamic>>.from(responseCurrent);

    // 2. Buscar despesas FIXAS de meses ANTERIORES
    // Elas devem ser projetadas neste mês
    final responseFixed = await _client
        .from('financial_transactions')
        .select()
        .eq('id_academia', idAcademia)
        .eq('type', 'expense')
        .eq('category', 'fixed')
        .lt('transaction_date', startOfMonth.toIso8601String());

    final fixedPast = List<Map<String, dynamic>>.from(responseFixed);

    // 3. Projetar despesas fixas passadas no mês atual

    // Otimização: Criar Set com descrições já pagas para lookup O(1)
    final paidFixedDescriptions = transactions
        .where((t) =>
            t['category'] == 'fixed' &&
            // Garantir que estamos olhando apenas despesas, embora category usually implies type
            t['type'] == 'expense')
        .map((t) => t['description'].toString().toLowerCase().trim())
        .toSet();

    for (var f in fixedPast) {
      final description = f['description'].toString().toLowerCase().trim();

      // Verificar se JÁ EXISTE uma transação real com esta descrição neste mês
      if (paidFixedDescriptions.contains(description)) continue;

      final originalDate = DateTime.parse(f['transaction_date']);

      // Ajustar dia para o mês alvo
      int day = originalDate.day;
      final daysInTargetMonth = endOfMonth.day;
      if (day > daysInTargetMonth) day = daysInTargetMonth;

      final newDate = DateTime(targetYear, targetMonth, day);

      final projected = Map<String, dynamic>.from(f);
      projected['transaction_date'] = newDate.toIso8601String().split('T')[0];

      // Projetar due_date também, se existir
      if (f['due_date'] != null) {
        final originalDueDate = DateTime.parse(f['due_date']);
        int dueDay = originalDueDate.day;
        if (dueDay > daysInTargetMonth) dueDay = daysInTargetMonth;
        projected['due_date'] = DateTime(targetYear, targetMonth, dueDay)
            .toIso8601String()
            .split('T')[0];
      }

      projected['is_projected'] = true; // Flag para identificar projeção
      projected['id'] =
          'proj_${f['id']}'; // ID fictício para não dar conflito de Key

      transactions.add(projected);
    }

    // 4. (NOVO) Enriquecer com nomes dos usuários
    await _enrichWithUserNames(transactions);

    // Reordenar tudo por data (decrescente)
    transactions.sort((a, b) {
      final dateA = DateTime.parse(a['transaction_date']);
      final dateB = DateTime.parse(b['transaction_date']);
      final cmp = dateB.compareTo(dateA);
      if (cmp != 0) return cmp;
      // Desempate por criação (se existir) ou ID
      return (b['created_at'] ?? '').compareTo(a['created_at'] ?? '');
    });

    return transactions;
  }

  // Helper para buscar nomes de usuários em lote
  static Future<void> _enrichWithUserNames(
      List<Map<String, dynamic>> transactions) async {
    final studentIds = <String>{};
    final trainerIds = <String>{};
    final nutritionistIds = <String>{};

    // 1. Coletar IDs
    for (var t in transactions) {
      final uid = t['related_user_id'] as String?;
      final role = t['related_user_role'] as String?;
      if (uid != null && role != null) {
        if (role == 'student') studentIds.add(uid);
        if (role == 'trainer') trainerIds.add(uid);
        if (role == 'nutritionist') nutritionistIds.add(uid);
      }
    }

    final namesMap = <String, String>{};

    // 2. Buscar nomes (em paralelo para performance)
    await Future.wait([
      if (studentIds.isNotEmpty)
        _client
            .from('users_alunos')
            .select('id, nome')
            .filter('id', 'in', studentIds.toList())
            .then((rows) {
          for (var r in rows) namesMap[r['id']] = r['nome'];
        }),
      if (trainerIds.isNotEmpty)
        _client
            .from('users_personal')
            .select('id, nome')
            .filter('id', 'in', trainerIds.toList())
            .then((rows) {
          for (var r in rows) namesMap[r['id']] = r['nome'];
        }),
      if (nutritionistIds.isNotEmpty)
        _client
            .from('users_nutricionista')
            .select('id, nome')
            .filter('id', 'in', nutritionistIds.toList())
            .then((rows) {
          for (var r in rows) namesMap[r['id']] = r['nome'];
        }),
    ]);

    // 3. Aplicar nomes
    for (var t in transactions) {
      final uid = t['related_user_id'] as String?;
      if (uid != null && namesMap.containsKey(uid)) {
        t['user_name'] = namesMap[uid];
      }
    }
  }

  // Obter resumo financeiro do mês (reutiliza getTransactions para consistência)
  static Future<Map<String, double>> getMonthlySummary({
    int? month,
    int? year,
  }) async {
    final transactions = await getTransactions(month: month, year: year);

    double income = 0;
    double expense = 0;
    double fixedExpense = 0;
    double variableExpense = 0;

    for (var t in transactions) {
      // Ignorar projeções (pendentes) no cálculo do saldo realizado
      if (t['is_projected'] == true) continue;

      final amount = (t['amount'] as num).toDouble();
      final type = t['type'];
      final category = t['category'];

      if (type == 'income') {
        income += amount;
      } else if (type == 'expense') {
        expense += amount;
        if (category == 'fixed') {
          fixedExpense += amount;
        } else if (category == 'variable') {
          variableExpense += amount;
        }
      }
    }

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
      'fixed_expense': fixedExpense,
      'variable_expense': variableExpense,
    };
  }

  // Obter resumo anual (lista de 12 meses + total do ano)
  static Future<Map<String, dynamic>> getAnnualSummary(int year) async {
    final idAcademia = await _getAcademyId();

    // 1. Buscar TODAS as transações do ano
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year, 12, 31);

    final responseYear = await _client
        .from('financial_transactions')
        .select()
        .eq('id_academia', idAcademia)
        .gte('transaction_date', startOfYear.toIso8601String())
        .lte('transaction_date', endOfYear.toIso8601String());

    final yearTransactions = List<Map<String, dynamic>>.from(responseYear);

    // 2. Buscar FIXAS anteriores ao ano (para projetar em Jan-Dez)
    final responseFixedPast = await _client
        .from('financial_transactions')
        .select()
        .eq('id_academia', idAcademia)
        .eq('type', 'expense')
        .eq('category', 'fixed')
        .lt('transaction_date', startOfYear.toIso8601String());

    final pastFixed = List<Map<String, dynamic>>.from(responseFixedPast);

    // Estrutura de retorno
    List<Map<String, dynamic>> monthsSummary = [];
    double totalIncome = 0;
    double totalExpense = 0;

    // Processar mês a mês
    for (int m = 1; m <= 12; m++) {
      // Transações REAIS deste mês
      final monthReal = yearTransactions.where((t) {
        final d = DateTime.parse(t['transaction_date']);
        return d.month == m;
      }).toList();

      // Otimização: Criar Set com descrições já pagas neste mês para evitar projeção duplicada
      final paidDescriptions = monthReal
          .where((t) => t['category'] == 'fixed' && t['type'] == 'expense')
          .map((t) => t['description'].toString().toLowerCase().trim())
          .toSet();

      // Somar valores REAIS
      double mIncome = 0;
      double mExpense = 0;

      for (var t in monthReal) {
        final val = (t['amount'] as num).toDouble();
        if (t['type'] == 'income') {
          mIncome += val;
        } else {
          mExpense += val;
        }
      }

      // Calcular Projeções (Fixas do passado + Fixas deste ano anteriores)
      // A) Fixas de anos anteriores
      for (var p in pastFixed) {
        final desc = p['description'].toString().toLowerCase().trim();
        // Se NÃO foi pago neste mês, soma como despesa projetada
        if (!paidDescriptions.contains(desc)) {
          mExpense += (p['amount'] as num).toDouble();
        }
      }

      // B) Fixas deste ano, criadas em meses anteriores ao atual 'm'
      // Atenção: Apenas 'expense' 'fixed'
      final thisYearFixedBefore = yearTransactions.where((t) {
        final d = DateTime.parse(t['transaction_date']);
        return t['category'] == 'fixed' &&
            t['type'] == 'expense' &&
            d.month < m;
      });

      for (var p in thisYearFixedBefore) {
        final desc = p['description'].toString().toLowerCase().trim();
        if (!paidDescriptions.contains(desc)) {
          mExpense += (p['amount'] as num).toDouble();
        }
      }

      monthsSummary.add({
        'month': m,
        'income': mIncome,
        'expense': mExpense,
        'balance': mIncome - mExpense,
      });

      totalIncome += mIncome;
      totalExpense += mExpense;
    }

    return {
      'year': year,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'total_balance': totalIncome - totalExpense,
      'months': monthsSummary,
    };
  }

  // Atualizar Transação
  static Future<void> updateTransaction({
    required String id,
    required String description,
    required double amount,
    required String type,
    required DateTime date,
    String? category, // 'fixed', 'variable'
    String? relatedUserId,
    String? relatedUserRole,
    DateTime? dueDate,
  }) async {
    await _client.from('financial_transactions').update({
      'description': description,
      'amount': amount,
      'type': type,
      'category': category,
      'transaction_date': date.toIso8601String().split('T')[0],
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'related_user_id': relatedUserId,
      'related_user_role': relatedUserRole,
    }).eq('id', id);
  }

  // Deletar transação
  static Future<void> deleteTransaction(String id) async {
    await _client.from('financial_transactions').delete().eq('id', id);
  }

  // Obter status de pagamento das mensalidades dos alunos
  static Future<List<Map<String, dynamic>>> getMonthlyPaymentsStatus({
    required int month,
    required int year,
  }) async {
    // 1. Buscar todos os alunos
    final students = await UserService.getUsersByRole(UserRole.student);

    // 2. Buscar transações de entrada deste mês
    final transactions = await getTransactions(month: month, year: year);
    final incomeTransactions = transactions
        .where((t) =>
            t['type'] == 'income' &&
            t['related_user_id'] != null &&
            t['related_user_role'] == 'student')
        .toList();

    // 3. Cruzar informações
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (var student in students) {
      final studentId = student['id'];
      final dueDay = student['payment_due_day'] as int?;

      // Verificar se pagou (procura transação vinculada ao aluno)
      final payments = incomeTransactions
          .where((t) => t['related_user_id'] == studentId)
          .toList();

      final isPaid = payments.isNotEmpty;
      final payment = isPaid ? payments.first : null;

      // Definir Status
      String status = 'pending'; // Pendente

      if (isPaid) {
        status = 'paid';
      } else {
        // Lógica de Vencido
        if (dueDay != null) {
          // Se o mês consultado é PASSADO, e não pagou -> Vencido
          if (year < now.year || (year == now.year && month < now.month)) {
            status = 'overdue';
          }
          // Se é o mês ATUAL e já passou do dia -> Vencido
          else if (year == now.year && month == now.month && now.day > dueDay) {
            status = 'overdue';
          }
        } else {
          // Sem dia de vencimento, se o mês já virou, considera vencido
          if (year < now.year || (year == now.year && month < now.month)) {
            status = 'overdue';
          }
        }
      }

      result.add({
        ...student,
        'status': status, // paid, pending, overdue
        'payment_date': payment != null ? payment['transaction_date'] : null,
        'payment_amount': payment != null ? payment['amount'] : 0.0,
        'payment_id': payment != null ? payment['id'] : null,
      });
    }

    // Ordenar: Vencidos -> Pendentes -> Pagos
    result.sort((a, b) {
      final statusOrder = {'overdue': 0, 'pending': 1, 'paid': 2};
      final statusA = statusOrder[a['status']] ?? 9;
      final statusB = statusOrder[b['status']] ?? 9;

      if (statusA != statusB) return statusA.compareTo(statusB);

      return (a['name'] as String).compareTo(b['name'] as String);
    });

    return result;
  }

  // Verificar se o aluno está inadimplente (Bloqueio de Acesso)
  static Future<bool> isStudentOverdue({
    required String studentId,
    required String idAcademia,
    int? paymentDueDay,
  }) async {
    if (paymentDueDay == null) return false;

    final now = DateTime.now();

    // Se hoje é ANTES ou IGUAL ao vencimento, está ok (Pendente)
    if (now.day <= paymentDueDay) return false;

    // Se passou do dia, verificamos se existe pagamento neste mês
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    // Formatar datas como YYYY-MM-DD para garantir compatibilidade com o banco
    final startStr = startOfMonth.toIso8601String().split('T')[0];
    final endStr = endOfMonth.toIso8601String().split('T')[0];

    try {
      final response = await _client
          .from('financial_transactions')
          .select('id')
          // .eq('id_academia', idAcademia) <-- REMOVIDO: Busca apenas pelo usuário para evitar erro de ID
          .eq('related_user_id', studentId)
          .eq('type', 'income')
          .gte('transaction_date', startStr)
          .lte('transaction_date', endStr)
          .maybeSingle();

      // Se encontrou transação (response != null), PAGOU -> Não está vencido (return false)
      return response == null;
    } catch (e) {
      print('Erro ao verificar status overdue: $e');
      // Em caso de erro, permitir acesso (fail open) para evitar travar usuários
      return false;
    }
  }

  // --- TRIGGER DE NOTIFICAÇÃO ---
  // Executar verificação de inadimplência e notificar
  static Future<Map<String, dynamic>> runOverdueCheckAndNotify() async {
    try {
      final now = DateTime.now();
      final statusList =
          await getMonthlyPaymentsStatus(month: now.month, year: now.year);

      // Filtra apenas os vencidos (overdue)
      final overdueStudents =
          statusList.where((s) => s['status'] == 'overdue').toList();

      if (overdueStudents.isEmpty) {
        return {
          'success': true,
          'message': 'Nenhum aluno inadimplente encontrado.'
        };
      }

      // 1. Notificar Alunos Vencidos
      for (var s in overdueStudents) {
        final studentId = s['id'].toString();
        await NotificationService.notifyPaymentOverdue(studentId);
      }

      // 2. Notificar Admin (Resumo)
      // Precisamos saber QUEM é o admin atual que chamou a função
      final currentUser = _client.auth.currentUser;
      if (currentUser != null) {
        // Verifica se quem chamou é Admin (segurança visual apenas)
        // Como o serviço é generico, vamos notificar o usuário LOGADO se ele for admin
        // Ou buscar TODOS os admins daquela academia?
        // Simplicidade: Notificar o usuário atual que disparou a ação
        final studentNames =
            overdueStudents.map((s) => s['name'].toString()).toList();
        await NotificationService.notifyAdminOverdueStudents(
            currentUser.id, studentNames);
      }

      return {
        'success': true,
        'message':
            'Notificações enviadas para ${overdueStudents.length} alunos e para o Admin.'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao processar notificações: $e'
      };
    }
  }
}
