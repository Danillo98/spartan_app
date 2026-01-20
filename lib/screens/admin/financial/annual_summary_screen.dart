import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../services/financial_service.dart';

class AnnualSummaryScreen extends StatefulWidget {
  const AnnualSummaryScreen({super.key});

  @override
  State<AnnualSummaryScreen> createState() => _AnnualSummaryScreenState();
}

class _AnnualSummaryScreenState extends State<AnnualSummaryScreen> {
  int _year = DateTime.now().year;
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await FinancialService.getAnnualSummary(_year);
      if (mounted) {
        setState(() {
          _data = data;
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

  void _changeYear(int delta) {
    setState(() => _year += delta);
    _loadData();
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  String _getMonthName(int month) {
    return DateFormat('MMMM', 'pt_BR').format(DateTime(2024, month, 1));
  }

  @override
  Widget build(BuildContext context) {
    final double totalBalance = _data?['total_balance'] ?? 0.0;
    final balanceColor =
        totalBalance >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Scaffold(
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
          'Resumo Anual',
          style: GoogleFonts.cinzel(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppTheme.borderGrey, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // Seletor de Ano
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: AppTheme.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _changeYear(-1),
                ),
                Text(
                  '$_year',
                  style: GoogleFonts.lato(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _changeYear(1),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Expanded(
              child:
                  Center(child: CircularProgressIndicator(color: Colors.black)),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Card Total Anual
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
                            'Resultado do Ano $_year',
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatCurrency(totalBalance),
                            style: GoogleFonts.lato(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: balanceColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMiniSummary(
                                'Entradas',
                                _data?['total_income'] ?? 0.0,
                                Colors.green[700]!,
                              ),
                              Container(
                                height: 20,
                                width: 1,
                                color: Colors.grey[300],
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 20),
                              ),
                              _buildMiniSummary(
                                'Saídas',
                                _data?['total_expense'] ?? 0.0,
                                Colors.red[700]!,
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Detalhamento Mensal',
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Lista de Meses
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _data?['months']?.length ?? 0,
                      itemBuilder: (context, index) {
                        final m = _data!['months'][index];
                        return _buildMonthItem(m);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniSummary(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(value),
          style: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthItem(Map<String, dynamic> m) {
    final balance = (m['balance'] as num).toDouble();
    final income = (m['income'] as num).toDouble();
    final expense = (m['expense'] as num).toDouble();
    final monthName = _getMonthName(m['month']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName.toUpperCase(),
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                _formatCurrency(balance),
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: balance >= 0 ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded,
                        size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      _formatCurrency(income),
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.arrow_downward_rounded,
                        size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      _formatCurrency(expense),
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
