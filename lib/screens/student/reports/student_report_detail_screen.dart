import 'package:flutter/material.dart';
import '../../../services/print_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final List<Map<String, dynamic>> allReports;

  const StudentReportDetailScreen({
    super.key,
    required this.report,
    required this.allReports,
  });

  @override
  State<StudentReportDetailScreen> createState() =>
      _StudentReportDetailScreenState();
}

class _StudentReportDetailScreenState extends State<StudentReportDetailScreen> {
  bool _isLoading = false;
  bool _isPrinting = false;

  Future<void> _openPrintPage() async {
    setState(() => _isPrinting = true);
    try {
      final studentName = widget.report['users_alunos']?['nome'] ??
          widget.report['student']?['name'] ??
          'Aluno';

      String professionalLabel = 'Nutricionista';
      String professionalName =
          widget.report['users_nutricionista']?['nome'] ?? 'Profissional';

      // Nota: No perfil do aluno, os relatórios são geralmente de nutricionistas,
      // mas podem ser de administradores ou personais também.
      // O join 'users_nutricionista' no PhysicalAssessmentService já tenta resolver isso.

      final weight = widget.report['weight']?.toDouble() ?? 0.0;
      double bf = 0.0;
      if (widget.report['body_fat_7_folds'] != null &&
          widget.report['body_fat_7_folds'] != 0) {
        bf = widget.report['body_fat_7_folds'].toDouble();
      } else if (widget.report['body_fat_3_folds'] != null &&
          widget.report['body_fat_3_folds'] != 0) {
        bf = widget.report['body_fat_3_folds'].toDouble();
      } else {
        bf = widget.report['body_fat']?.toDouble() ?? 0.0;
      }

      double muscleMass = 0.0;
      if (weight > 0 && bf > 0) {
        muscleMass = weight * (1 - (bf / 100));
      }

      final printData = {
        'student_name': studentName,
        'professional_name': professionalName,
        'professional_label': professionalLabel,
        'assessment_date': widget.report['assessment_date'],
        'weight': weight,
        'height': widget.report['height'],
        'body_fat': bf,
        'muscle_mass': muscleMass,
        'chest': widget.report['chest'],
        'waist': widget.report['waist'],
        'abdomen': widget.report['abdomen'],
        'hips': widget.report['hips'],
        'right_arm': widget.report['right_arm'],
        'left_arm': widget.report['left_arm'],
        'right_thigh': widget.report['right_thigh'],
        'left_thigh': widget.report['left_thigh'],
        'right_calf': widget.report['right_calf'],
        'left_calf': widget.report['left_calf'],
        'shoulder': widget.report['shoulder'],
        'right_forearm': widget.report['right_forearm'],
        'left_forearm': widget.report['left_forearm'],
        'skinfold_chest': widget.report['skinfold_chest'],
        'skinfold_abdomen': widget.report['skinfold_abdomen'],
        'skinfold_thigh': widget.report['skinfold_thigh'],
        'skinfold_calf': widget.report['skinfold_calf'],
        'skinfold_triceps': widget.report['skinfold_triceps'],
        'skinfold_biceps': widget.report['skinfold_biceps'],
        'skinfold_subscapular': widget.report['skinfold_subscapular'],
        'skinfold_suprailiac': widget.report['skinfold_suprailiac'],
        'skinfold_midaxillary': widget.report['skinfold_midaxillary'],
        'body_fat_3_folds': widget.report['body_fat_3_folds'],
        'body_fat_7_folds': widget.report['body_fat_7_folds'],
        'gender': widget.report['gender'],
        'student_birth_date': widget.report['student_birth_date'],
      };

      await PrintService.printReport(
        data: printData,
        templateName: 'print-evolution.html',
        localStorageKey: 'spartan_evolution_print',
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

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    final date = DateTime.parse(report['assessment_date']);
    final nutritionist =
        report['users_nutricionista']?['nome'] ?? 'Nutricionista';

    // Prepare data directly
    final weight = report['weight']?.toDouble() ?? 0.0;

    // Lógica para priorizar dobras (Dobras 7 > Dobras 3 > Manual)
    double bodyFat = 0.0;
    if (report['body_fat_7_folds'] != null && report['body_fat_7_folds'] != 0) {
      bodyFat = report['body_fat_7_folds'].toDouble();
    } else if (report['body_fat_3_folds'] != null &&
        report['body_fat_3_folds'] != 0) {
      bodyFat = report['body_fat_3_folds'].toDouble();
    } else {
      bodyFat = report['body_fat']?.toDouble() ?? 0.0;
    }

    // Calcular Massa Muscular (Massa Magra em kg)
    double muscleMass = 0.0;
    if (weight > 0 && bodyFat > 0) {
      muscleMass = weight * (1 - (bodyFat / 100));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          title: Text(
            'Avaliação Física',
            style: GoogleFonts.cinzel(
              color: AppTheme.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppTheme.secondaryText),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon:
                  const Icon(Icons.print_rounded, color: AppTheme.primaryText),
              onPressed: (_isLoading || _isPrinting) ? null : _openPrintPage,
              tooltip: 'Imprimir Avaliação',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info
                  _buildHeaderCard(date, nutritionist),
                  const SizedBox(height: 24),

                  Text(
                    'Resumo Principal',
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Peso (kg)',
                          value: weight.toStringAsFixed(1),
                          icon: Icons.monitor_weight_outlined,
                          color: const Color(0xFF457B9D),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: '% Gordura',
                          value: '${bodyFat.toStringAsFixed(1)}%',
                          icon: Icons.opacity_rounded,
                          color: AppTheme.primaryRed,
                        ),
                      ),
                      if (muscleMass > 0) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Massa Musc. (kg)',
                            value: muscleMass.toStringAsFixed(1),
                            icon: Icons.fitness_center_rounded,
                            color: const Color(0xFF2A9D8F),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 32),
                  Text(
                    'Medidas Detalhadas',
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMeasurementsGrid(report),

                  if (report['notes'] != null &&
                      report['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Observações',
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderGrey),
                      ),
                      child: Text(
                        report['notes'],
                        style: GoogleFonts.lato(
                            fontSize: 15,
                            color: AppTheme.secondaryText,
                            height: 1.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
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
                          CircularProgressIndicator(color: AppTheme.primaryRed),
                          SizedBox(height: 16),
                          Text('Gerando PDF...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(DateTime date, String nutriName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF457B9D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Color(0xFF457B9D),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat("dd 'de' MMMM, yyyy", 'pt_BR').format(date),
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Avaliado por: $nutriName',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 140, // Altura fixa para igualar todos os cards (UX solicitada)
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: GoogleFonts.lato(
                fontSize: 12,
                color: AppTheme.secondaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsGrid(Map<String, dynamic> report) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildMeasureRow('Ombro', report['shoulder']),
          _buildMeasureRow('Peitoral', report['chest']),
          _buildMeasureRow('Cintura', report['waist']),
          _buildMeasureRow('Abdômen', report['abdomen']),
          _buildMeasureRow('Quadril', report['hips']),
          const Divider(height: 24),
          _buildMeasureRow('Braço Dir.', report['right_arm']),
          _buildMeasureRow('Braço Esq.', report['left_arm']),
          _buildMeasureRow('Ante-braço Dir.', report['right_forearm']),
          _buildMeasureRow('Ante-braço Esq.', report['left_forearm']),
          const Divider(height: 24),
          _buildMeasureRow('Coxa Dir.', report['right_thigh']),
          _buildMeasureRow('Coxa Esq.', report['left_thigh']),
          _buildMeasureRow('Perna Dir.', report['right_calf']),
          _buildMeasureRow('Perna Esq.', report['left_calf']),
          if (report['workout_focus'] != null) ...[
            const Divider(height: 24),
            _buildMeasureTextRow('Foco do Treino', report['workout_focus']),
          ],
          if (report['body_fat_3_folds'] != null ||
              report['body_fat_7_folds'] != null) ...[
            const Divider(height: 24),
            if (report['body_fat_3_folds'] != null)
              _buildMeasureRow(
                  '%G Pollock 3 Dobras', report['body_fat_3_folds'],
                  unit: '%'),
            if (report['body_fat_7_folds'] != null)
              _buildMeasureRow(
                  '%G Pollock 7 Dobras', report['body_fat_7_folds'],
                  unit: '%'),
          ],
        ],
      ),
    );
  }

  Widget _buildMeasureRow(String label, dynamic value, {String? unit}) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 15,
              color: AppTheme.secondaryText,
            ),
          ),
          Text(
            '${value.toString()} ${unit ?? 'cm'}',
            style: GoogleFonts.lato(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasureTextRow(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 15,
              color: AppTheme.secondaryText,
            ),
          ),
          Text(
            value.toString(),
            style: GoogleFonts.lato(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// Chart Helpers
class ChartPoint {
  final DateTime date;
  final double value;
  ChartPoint({required this.date, required this.value});
}

class SimpleLineChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final Color lineColor;

  SimpleLineChartPainter({required this.points, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final padding = 30.0; // Margem para textos
    final w = size.width - (padding * 2);
    final h = size.height - (padding * 2);

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final axisPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;

    // Calc ranges
    double minVal = points.map((p) => p.value).reduce(min);
    double maxVal = points.map((p) => p.value).reduce(max);

    // Add some padding to range
    double range = maxVal - minVal;
    if (range == 0) range = 10;
    minVal -= range * 0.2; // Mais espaço embaixo
    maxVal += range * 0.2; // Mais espaço em cima

    range = maxVal - minVal;

    // Shift canvas for padding
    canvas.save();
    canvas.translate(padding, padding);

    // Draw Grid (3 lines)
    for (int i = 0; i <= 2; i++) {
      final y = h - (h * (i / 2));
      canvas.drawLine(Offset(0, y), Offset(w, y), axisPaint);
    }

    // path
    final path = Path();
    final List<Offset> pointOffsets = [];

    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * w;
      final normalizedVal = (points[i].value - minVal) / range;
      final y = h - (normalizedVal * h);

      pointOffsets.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw dots and labels
    for (int i = 0; i < points.length; i++) {
      final offset = pointOffsets[i];
      final point = points[i];

      // Dot
      final dotPaint = Paint()..color = lineColor;
      canvas.drawCircle(offset, 5, dotPaint);
      canvas.drawCircle(offset, 3, Paint()..color = Colors.white);

      // Value Label (Above)
      final textSpan = TextSpan(
        text: point.value.toStringAsFixed(1),
        style: TextStyle(
          color: lineColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(offset.dx - (textPainter.width / 2), offset.dy - 20),
      );

      // Date Label (Below)
      // Show date only for first, last, or if few points to avoid clutter
      if (points.length <= 5 || i == 0 || i == points.length - 1) {
        final dateText = DateFormat('dd/MM').format(point.date);
        final dateSpan = TextSpan(
          text: dateText,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        );
        final datePainter = TextPainter(
          text: dateSpan,
          textDirection: ui.TextDirection.ltr,
        );
        datePainter.layout();
        datePainter.paint(
          canvas,
          Offset(offset.dx - (datePainter.width / 2), h + 10),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
