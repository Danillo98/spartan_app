import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../services/financial_service.dart';

class MonthlyPaymentScreen extends StatefulWidget {
  const MonthlyPaymentScreen({super.key});

  @override
  State<MonthlyPaymentScreen> createState() => _MonthlyPaymentScreenState();
}

class _MonthlyPaymentScreenState extends State<MonthlyPaymentScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  DateTime _currentDate = DateTime.now();
  String _currentFilter = 'all'; // 'all', 'paid', 'pending', 'overdue'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await FinancialService.getMonthlyPaymentsStatus(
        month: _currentDate.month,
        year: _currentDate.year,
      );

      if (mounted) {
        setState(() {
          _students = data;
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
    _loadData();
  }

  List<Map<String, dynamic>> get _filteredList {
    return _students.where((s) {
      // Filtro de Nome
      final nameMatches = (s['name'] as String)
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());

      // Filtro de Status
      bool statusMatches = true;
      if (_currentFilter != 'all') {
        statusMatches = s['status'] == _currentFilter;
        // Agrupar 'pending' e 'overdue' se o filtro for 'pending'?
        // O user pediu: PAGO, NÃO PAGO (que inclui vencido?), VENCIDOS.
        // Vou assumir:
        // PAGO -> 'paid'
        // NÃO PAGO -> 'pending' (mas 'overdue' tambem nao está pago).
        // Se usar filtro "NÃO PAGO", mostrar pending E overdue?
        // O user disse: "filtrar pro PAGO, NÃO PAGO e VENCIDOS".
        // Vou fazer literal:
        if (_currentFilter == 'pending') {
          // Mostrar pending E overdue (ambos não pagos)
          statusMatches = s['status'] == 'pending' || s['status'] == 'overdue';
        } else if (_currentFilter == 'overdue') {
          // Apenas vencidos
          statusMatches = s['status'] == 'overdue';
        }
      }

      return nameMatches && statusMatches;
    }).toList();
  }

  Future<void> _registerPayment(Map<String, dynamic> student) async {
    final amountController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Registrar Pagamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aluno: ${student['name']}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true && amountController.text.isNotEmpty) {
      try {
        final amount =
            double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;

        await FinancialService.addTransaction(
          description: 'Mensalidade - ${student['name']}',
          amount: amount,
          type: 'income',
          date: DateTime.now(), // Data do pagamento é HOJE
          category: 'Mensalidade',
          relatedUserId: student['id'],
          relatedUserRole: 'student',
        );

        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Pagamento registrado com sucesso!'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erro ao registrar: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _undoPayment(Map<String, dynamic> student) async {
    if (student['payment_id'] == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estornar Pagamento'),
        content: const Text(
            'Deseja cancelar o registro deste pagamento? A transação financeira será removida.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Estornar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FinancialService.deleteTransaction(student['payment_id']);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Pagamento estornado.'),
                backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erro ao estornar: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text(
          'Mensalidades',
          style: GoogleFonts.cinzel(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.secondaryText),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppTheme.borderGrey, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // Header: Mês e Pesquisa
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.white,
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
                const SizedBox(height: 16),
                // Pesquisa
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Pesquisar Aluno...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppTheme.lightGrey,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ],
            ),
          ),

          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('Todos', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Pagos', 'paid', Colors.green),
                const SizedBox(width: 8),
                _buildFilterChip('Não Pagos', 'pending', Colors.orange),
                const SizedBox(width: 8),
                _buildFilterChip('Vencidos', 'overdue', Colors.red),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredList.isEmpty
                    ? const Center(child: Text('Nenhum aluno encontrado'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredList.length,
                        itemBuilder: (context, index) {
                          return _buildStudentCard(_filteredList[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, [Color? color]) {
    final isSelected = _currentFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _currentFilter = value);
      },
      selectedColor: color ?? Colors.black,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
          color: isSelected || color == null
              ? Colors.transparent
              : Colors.grey.shade300),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final status = student['status']; // paid, pending, overdue
    final dueDay = student['payment_due_day'];

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'paid') {
      statusColor = Colors.green;
      statusLabel = 'PAGO';
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'overdue') {
      statusColor = Colors.red;
      statusLabel = 'VENCIDO';
      statusIcon = Icons.warning_rounded;
    } else {
      statusColor = Colors.orange;
      statusLabel = 'NÃO PAGO';
      statusIcon = Icons.schedule_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar / Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['name'] ?? 'Aluno',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Vencimento: Dia ${dueDay ?? '?'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Ação
            if (status == 'paid')
              IconButton(
                icon: const Icon(Icons.undo_rounded, color: Colors.grey),
                tooltip: 'Estornar',
                onPressed: () => _undoPayment(student),
              )
            else
              ElevatedButton(
                onPressed: () => _registerPayment(student),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Receber'),
              ),
          ],
        ),
      ),
    );
  }
}
