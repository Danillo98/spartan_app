import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/print_service.dart';
import '../../../config/app_theme.dart';
import '../../../services/financial_service.dart';
import '../../../widgets/subscription_check.dart';
import 'add_transaction_screen.dart';
import 'annual_summary_screen.dart';

class FinancialDashboardScreen extends StatefulWidget {
  const FinancialDashboardScreen({super.key});

  @override
  State<FinancialDashboardScreen> createState() =>
      _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState extends State<FinancialDashboardScreen> {
  bool _isLoading = true;
  bool _isBlocked = false; // Flag para saber se está bloqueado
  bool _isPrinting = false;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, double> _summary = {
    'income': 0.0,
    'expense': 0.0,
    'balance': 0.0,
    'fixed_expense': 0.0,
    'variable_expense': 0.0,
  };

  DateTime _currentDate = DateTime.now();
  String _currentFilter = 'all'; // 'all', 'income', 'fixed', 'variable'
  String _searchQuery = '';
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    // Usar addPostFrameCallback para garantir que o context esteja pronto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoad();
    });
  }

  Future<void> _checkAndLoad() async {
    // Verifica assinatura antes de carregar a tela
    final canProceed = await checkSubscription(context);
    if (!canProceed) {
      // Marcar como bloqueado para impedir voltar pelo navegador
      if (mounted) {
        setState(() {
          _isBlocked = true;
          _isLoading = false;
        });
      }
      return;
    }
    _loadUncut();
  }

  Future<void> _loadUncut() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await FinancialService.getTransactions(
        month: _currentDate.month,
        year: _currentDate.year,
      );
      final summary = await FinancialService.getMonthlySummary(
        month: _currentDate.month,
        year: _currentDate.year,
      );

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  void _changeMonth(int increment) {
    setState(() {
      _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month + increment,
        1,
      );
    });
    _loadUncut();
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    // 1. Filtro base (Tipo)
    List<Map<String, dynamic>> baseList;
    if (_currentFilter == 'all') {
      baseList = _transactions;
    } else if (_currentFilter == 'income') {
      baseList = _transactions.where((t) => t['type'] == 'income').toList();
    } else if (_currentFilter == 'fixed') {
      baseList = _transactions
          .where((t) => t['type'] == 'expense' && t['category'] == 'fixed')
          .toList();
    } else if (_currentFilter == 'variable') {
      baseList = _transactions
          .where((t) => t['type'] == 'expense' && t['category'] == 'variable')
          .toList();
    } else {
      baseList = _transactions;
    }

    // 2. Filtro de Data Específica
    if (_filterDate != null) {
      baseList = baseList.where((t) {
        final tDate = DateTime.parse(t['transaction_date']);
        return tDate.year == _filterDate!.year &&
            tDate.month == _filterDate!.month &&
            tDate.day == _filterDate!.day;
      }).toList();
    }

    // 3. Filtro de Pesquisa (Texto)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      baseList = baseList.where((t) {
        final description = t['description'].toString().toLowerCase();
        final amount = t['amount'].toString();
        final userName = (t['user_name'] ?? '').toString().toLowerCase();

        return description.contains(query) ||
            amount.contains(query) ||
            userName.contains(query);
      }).toList();
    }

    return baseList;
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  Future<void> _deleteTransaction(String id) async {
    try {
      await FinancialService.deleteTransaction(id);
      _loadUncut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transação removida')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover: $e')),
        );
      }
    }
  }

  Future<void> _editTransaction(Map<String, dynamic> transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTransactionScreen(transactionToEdit: transaction),
      ),
    );
    if (result == true) {
      _loadUncut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceColor = _summary['balance']! >= 0
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return PopScope(
      canPop: !_isBlocked, // Impede voltar se bloqueado
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppTheme.lightGrey,
            appBar: AppBar(
              backgroundColor: AppTheme.white,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: AppTheme.secondaryText),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Controle Financeiro',
                style: GoogleFonts.cinzel(
                  color: AppTheme.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.print_rounded,
                      color: AppTheme.primaryText),
                  onPressed: _openPrintPage,
                  tooltip: 'Imprimir Relatório Mensal',
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(color: AppTheme.borderGrey, height: 1.0),
              ),
            ),
            body: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.black))
                : RefreshIndicator(
                    onRefresh: _loadUncut,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Seletor de Mês
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded),
                                onPressed: () => _changeMonth(-1),
                              ),
                              Text(
                                DateFormat('MMMM yyyy', 'pt_BR')
                                    .format(_currentDate)
                                    .toUpperCase(),
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryText,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded),
                                onPressed: () => _changeMonth(1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Card Saldo
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Saldo em Caixa',
                                  style: GoogleFonts.lato(
                                    fontSize: 14,
                                    color: AppTheme.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatCurrency(_summary['balance']!),
                                  style: GoogleFonts.lato(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: balanceColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Resumo Entradas / Saídas
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Entradas',
                                  _summary['income']!,
                                  const Color(0xFF2E7D32),
                                  Icons.arrow_upward_rounded,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Saídas',
                                  _summary['expense']!,
                                  const Color(0xFFC62828),
                                  Icons.arrow_downward_rounded,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Barra de Pesquisa e Filtro de Data
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (value) =>
                                      setState(() => _searchQuery = value),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Buscar por nome, valor ou descrição',
                                    prefixIcon:
                                        const Icon(Icons.search_rounded),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: _filterDate != null
                                      ? Colors.black
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.calendar_month_rounded,
                                    color: _filterDate != null
                                        ? Colors.white
                                        : Colors.grey[700],
                                  ),
                                  onPressed: () async {
                                    if (_filterDate != null) {
                                      setState(() => _filterDate = null);
                                      return;
                                    }
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _currentDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme:
                                                const ColorScheme.light(
                                              primary: Colors.black,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _filterDate = picked;
                                        // Se a data escolhida for de outro mês, atualiza a visão
                                        if (picked.month !=
                                                _currentDate.month ||
                                            picked.year != _currentDate.year) {
                                          _currentDate = picked;
                                          _loadUncut();
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Filtros (Chips)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('Todos', 'all'),
                                const SizedBox(width: 8),
                                _buildFilterChip('Entradas', 'income'),
                                const SizedBox(width: 8),
                                _buildFilterChip('Fixos', 'fixed'),
                                const SizedBox(width: 8),
                                _buildFilterChip('Variáveis', 'variable'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Lista de Transações (Header)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Histórico',
                                style: GoogleFonts.lato(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryText,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const AnnualSummaryScreen()),
                                  );
                                },
                                icon: const Icon(Icons.calendar_today_rounded,
                                    size: 14, color: AppTheme.primaryText),
                                label: Text(
                                  'Resumo Anual',
                                  style: GoogleFonts.lato(
                                    color: AppTheme.primaryText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_filteredTransactions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long_rounded,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhuma transação encontrada',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredTransactions.length,
                              itemBuilder: (context, index) {
                                final t = _filteredTransactions[index];
                                return _buildTransactionItem(t);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddTransactionScreen()),
                );
                if (result == true) {
                  _loadUncut();
                }
              },
              backgroundColor: const Color(0xFF1A1A1A),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('NOVA TRANSAÇÃO',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          if (_isPrinting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.black),
                        SizedBox(height: 16),
                        Text('Gerando Relatório...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ), // Fecha PopScope
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _currentFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _currentFilter = value);
        }
      },
      selectedColor: Colors.black,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: isSelected ? Colors.black : Colors.grey.shade300),
    );
  }

  Widget _buildSummaryCard(
      String title, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(value),
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _payExpense(Map<String, dynamic> t) async {
    setState(() => _isLoading = true);
    try {
      await FinancialService.addTransaction(
        description: t['description'],
        amount: (t['amount'] as num).toDouble(),
        type: t['type'],
        date: DateTime.parse(t[
            'transaction_date']), // Data projetada (já ajustada para este mês)
        category: t['category'],
        relatedUserId: t['related_user_id'],
        relatedUserRole: t['related_user_role'],
        dueDate: t['due_date'] != null ? DateTime.parse(t['due_date']) : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta paga com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadUncut();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao pagar conta: $e')),
        );
      }
    }
  }

  Widget _buildTransactionItem(Map<String, dynamic> t) {
    final isIncome = t['type'] == 'income';
    final amount = (t['amount'] as num).toDouble();
    final date = DateTime.parse(t['transaction_date']);
    final category = t['category'];
    final userRole = t['related_user_role'];

    // Simplificar label de função
    String? userRoleLabel;
    if (userRole == 'student')
      userRoleLabel = 'Aluno';
    else if (userRole == 'trainer')
      userRoleLabel = 'Personal';
    else if (userRole == 'nutritionist') userRoleLabel = 'Nutri';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Ícone In/Out
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isIncome
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: isIncome ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Informações Centrais
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t['description'],
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Tipo (Fixo / Variável)
                    if (category != null && !isIncome)
                      Text(
                        category == 'fixed' ? 'FIXO' : 'VARIÁVEL',
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[600],
                        ),
                      ),

                    // Pagamento (Só mostra se não for projeção)
                    if (t['is_projected'] != true) ...[
                      Text(' • ', style: TextStyle(color: Colors.grey[400])),
                      Text(
                        'PAGO ${DateFormat('dd/MM').format(date)}',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: const Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],

                    // Vencimento
                    if (t['due_date'] != null) ...[
                      Text(' • ', style: TextStyle(color: Colors.grey[400])),
                      Text(
                        'Venc: ${DateFormat('dd/MM').format(DateTime.parse(t['due_date']))}',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: (t['is_projected'] == true &&
                                  DateTime.parse(t['due_date']).isBefore(
                                      DateTime.now()
                                          .subtract(const Duration(days: 1))))
                              ? Colors.red[800]
                              : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],

                    // Label de Usuário e Nome
                    if (t['user_name'] != null || userRoleLabel != null) ...[
                      Text(' • ', style: TextStyle(color: Colors.grey[400])),
                      Text(
                        [
                          t['user_name'],
                          (userRoleLabel != null ? '($userRoleLabel)' : null)
                        ].where((e) => e != null).join(' ').toUpperCase(),
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Coluna da Direita (Valor + Ações)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isIncome
                    ? '+ ${_formatCurrency(amount)}'
                    : '- ${_formatCurrency(amount)}',
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isIncome ? Colors.green[700] : Colors.red[700],
                ),
              ),
              const SizedBox(height: 4),

              // Status e Ações para Despesas Fixas
              if (t['is_projected'] == true) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PENDENTE',
                    style: GoogleFonts.lato(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    onPressed: () => _payExpense(t),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'PAGAR AGORA',
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Transação Real
                if (t['type'] == 'expense' && t['category'] == 'fixed')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PAGO',
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botão Editar
                    InkWell(
                      onTap: () => _editTransaction(t),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Botão Excluir
                    InkWell(
                      onTap: () async {
                        final confirm = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: const Text('Excluir Transação'),
                            content: const Text(
                                'Tem certeza que deseja apagar este registro?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar')),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Excluir',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          _deleteTransaction(t['id']);
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.red[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPrintPage() async {
    setState(() => _isPrinting = true);

    try {
      final printData = {
        'month_name': DateFormat('MMMM', 'pt_BR').format(_currentDate),
        'year': _currentDate.year,
        'summary': _summary,
        'transactions': _transactions,
      };

      await PrintService.printReport(
        data: printData,
        templateName: 'print-financial-monthly.html',
        localStorageKey: 'spartan_financial_monthly_print',
      );

      if (mounted) setState(() => _isPrinting = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir impressão: $e')),
        );
      }
    }
  }
}
