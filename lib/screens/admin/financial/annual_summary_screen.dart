import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
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
  bool _isPrinting = false;
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

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  String _getMonthName(int month) {
    final months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final balanceColor = (_data?['total_balance'] ?? 0) >= 0
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return Stack(
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
              'Resumo Anual',
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
                tooltip: 'Imprimir Resumo Anual',
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(color: AppTheme.borderGrey, height: 1.0),
            ),
          ),
          body: Column(
            children: [
              // Seletor de Ano
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () {
                        setState(() => _year--);
                        _loadData();
                      },
                    ),
                    Text(
                      _year.toString(),
                      style: GoogleFonts.cinzel(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () {
                        setState(() => _year++);
                        _loadData();
                      },
                    ),
                  ],
                ),
              ),

              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  ),
                )
              else if (_data == null)
                const Expanded(
                  child: Center(child: Text('Nenhum dado encontrado')),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Card Resumo Grande
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
                                'Resultado do Exercício',
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  color: AppTheme.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatCurrency(_data!['total_balance']),
                                style: GoogleFonts.lato(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: balanceColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildMiniSummary(
                                    'Total Entradas',
                                    _data!['total_income'],
                                    const Color(0xFF2E7D32),
                                  ),
                                  _buildMiniSummary(
                                    'Total Saídas',
                                    _data!['total_expense'],
                                    const Color(0xFFC62828),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Detalhamento Mensal',
                            style: GoogleFonts.cinzel(
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
                      Text('Gerando Resumo Anual...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
                        color: Colors.grey[600],
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
                        color: Colors.grey[600],
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

  Future<void> _openPrintPage() async {
    if (_data == null) return;
    setState(() => _isPrinting = true);

    try {
      final printData = {
        'year': _year,
        'total_balance': _data!['total_balance'],
        'total_income': _data!['total_income'],
        'total_expense': _data!['total_expense'],
        'months': _data!['months'],
      };

      final jsonData = jsonEncode(printData);
      final blob = html.Blob([jsonData], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final baseUrl = html.window.location.origin;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final printUrl =
          '$baseUrl/print-financial-annual.html?v=$timestamp&dataUrl=$url';

      if (mounted) setState(() => _isPrinting = false);

      html.window.open(printUrl, '_blank');

      Future.delayed(const Duration(seconds: 20), () {
        html.Url.revokeObjectUrl(url);
      });
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
