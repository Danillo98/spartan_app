import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'user_service.dart';
import '../models/user_role.dart';

class FinancialService {
  static final SupabaseClient _client = SupabaseService.client;

  // Obter CNPJ da academia atual (contexto)
  static Future<String> _getAcademyCnpj() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    // Tentar buscar do cache local ou DB
    final admin = await _client
        .from('users_adm')
        .select('cnpj_academia')
        .eq('id', user.id)
        .maybeSingle();

    if (admin != null) return admin['cnpj_academia'];
    throw Exception('Academia não encontrada');
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
  }) async {
    final cnpj = await _getAcademyCnpj();

    await _client.from('financial_transactions').insert({
      'cnpj_academia': cnpj,
      'description': description,
      'amount': amount,
      'type': type,
      'category': category,
      'transaction_date': date.toIso8601String().split('T')[0],
      'related_user_id': relatedUserId,
      'related_user_role': relatedUserRole,
    });
  }

  // Buscar transações (com replicação de fixas)
  static Future<List<Map<String, dynamic>>> getTransactions({
    int? month,
    int? year,
  }) async {
    final cnpj = await _getAcademyCnpj();
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
        .eq('cnpj_academia', cnpj)
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
        .eq('cnpj_academia', cnpj)
        .eq('type', 'expense')
        .eq('category', 'fixed')
        .lt('transaction_date', startOfMonth.toIso8601String());

    final fixedPast = List<Map<String, dynamic>>.from(responseFixed);

    // 3. Projetar despesas fixas passadas no mês atual
    for (var f in fixedPast) {
      final description = f['description'].toString().toLowerCase();

      // Verificar se JÁ EXISTE uma transação real com esta descrição neste mês
      // Se existir, significa que já foi paga (realizada), então não projetamos
      final alreadyPaid = transactions.any((t) =>
          t['description'].toString().toLowerCase() == description &&
          t['category'] == 'fixed');

      if (alreadyPaid) continue;

      final originalDate = DateTime.parse(f['transaction_date']);

      // Ajustar dia para o mês alvo
      int day = originalDate.day;
      final daysInTargetMonth = endOfMonth.day;
      if (day > daysInTargetMonth) day = daysInTargetMonth;

      final newDate = DateTime(targetYear, targetMonth, day);

      final projected = Map<String, dynamic>.from(f);
      projected['transaction_date'] = newDate.toIso8601String().split('T')[0];
      projected['is_projected'] = true; // Flag para identificar projeção
      projected['id'] =
          'proj_${f['id']}'; // ID fictício para não dar conflito de Key

      transactions.add(projected);
    }

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
    final cnpj = await _getAcademyCnpj();

    // 1. Buscar TODAS as transações do ano
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year, 12, 31);

    final responseYear = await _client
        .from('financial_transactions')
        .select()
        .eq('cnpj_academia', cnpj)
        .gte('transaction_date', startOfYear.toIso8601String())
        .lte('transaction_date', endOfYear.toIso8601String());

    final yearTransactions = List<Map<String, dynamic>>.from(responseYear);

    // 2. Buscar FIXAS anteriores ao ano (para projetar em Jan-Dez)
    final responseFixedPast = await _client
        .from('financial_transactions')
        .select()
        .eq('cnpj_academia', cnpj)
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

      // Transações FIXAS do passado projetadas
      // E TAMBÉM as fixas criadas NESTE ANO em meses anteriores a 'm'
      // Ex: Estou no mês 3 (Março).
      // PastFixed (ano < year) -> Projeta
      // YearFixed (ano == year, mês < 3) -> Projeta

      List<Map<String, dynamic>> projected = [];

      // A) Fixas de anos anteriores
      projected.addAll(pastFixed);

      // B) Fixas deste ano, de meses anteriores
      final thisYearFixedBefore = yearTransactions.where((t) {
        final d = DateTime.parse(t['transaction_date']);
        return t['type'] == 'expense' &&
            t['category'] == 'fixed' &&
            d.month < m;
      });
      projected.addAll(thisYearFixedBefore);

      // Somar valores
      double mIncome = 0;
      double mExpense = 0;

      // Somar reais
      for (var t in monthReal) {
        final val = (t['amount'] as num).toDouble();
        if (t['type'] == 'income')
          mIncome += val;
        else
          mExpense += val;
      }

      // Somar projetadas
      for (var p in projected) {
        // Nenhuma projetada é Income (só Expense Fixed)
        final val = (p['amount'] as num).toDouble();
        mExpense += val;
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
  }) async {
    await _client.from('financial_transactions').update({
      'description': description,
      'amount': amount,
      'type': type,
      'category': category,
      'transaction_date': date.toIso8601String().split('T')[0],
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
    required String cnpjAcademia,
    int? paymentDueDay,
  }) async {
    // Se não tiver dia de vencimento, a rigor não vence (ou assume dia 1, ou 10? Regra de negócio)
    // Vamos assumir que se não tem dueDay definido, não bloqueia por enquanto.
    if (paymentDueDay == null) return false;

    final now = DateTime.now();

    // Se hoje é ANTES do vencimento, está ok (mesmo que não tenha pago ainda)
    if (now.day <= paymentDueDay) return false;

    // Se passou do dia, precisamos ver se pagou NESTE MÊS/ANO
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    // Buscar pagamento
    final response = await _client
        .from('financial_transactions')
        .select()
        .eq('cnpj_academia', cnpjAcademia)
        .eq('related_user_id', studentId)
        .eq('type', 'income') // Pagamento é entrada
        .gte('transaction_date', startOfMonth.toIso8601String())
        .lte('transaction_date', endOfMonth.toIso8601String())
        .maybeSingle();

    // Se encontrou transação -> Pagou (false overdue)
    // Se null -> Não pagou (true overdue)
    return response == null;
  }
}
