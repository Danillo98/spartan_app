import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import 'dart:math';

class StudentReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  final List<Map<String, dynamic>> allReports;

  const StudentReportDetailScreen({
    super.key,
    required this.report,
    required this.allReports,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(report['assessment_date']);
    final nutritionist =
        report['users_nutricionista']?['nome'] ?? 'Nutricionista';

    // Prepare data directly
    final weight = report['weight']?.toDouble() ?? 0.0;
    final bodyFat = report['body_fat']?.toDouble() ?? 0.0;
    final muscleMass = report['muscle_mass']?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text(
          'Detalhes Físicos',
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
      ),
      body: SingleChildScrollView(
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
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    title: '% Gordura',
                    value: '$bodyFat%',
                    icon: Icons.opacity_rounded,
                    color: AppTheme.primaryRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (muscleMass > 0)
              _buildMetricCard(
                title: 'Massa Muscular (%)',
                value: '$muscleMass%',
                icon: Icons.fitness_center_rounded,
                color: const Color(0xFF2A9D8F),
              ),

            // Charts Section
            if (allReports.length > 1) ...[
              const SizedBox(height: 32),
              Text(
                'Sua Evolução',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              const SizedBox(height: 16),
              _buildChartSection(),
            ],

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
            _buildMeasurementsGrid(),

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
                      fontSize: 15, color: AppTheme.secondaryText, height: 1.5),
                ),
              ),
            ],
            const SizedBox(height: 40),
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
      padding: const EdgeInsets.all(20),
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
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 12,
              color: AppTheme.secondaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    // Extract history sorted by date ascending
    final history = List<Map<String, dynamic>>.from(allReports);
    history.sort((a, b) => DateTime.parse(a['assessment_date'])
        .compareTo(DateTime.parse(b['assessment_date'])));

    // Prepare data points for weight
    final points = history
        .map((h) {
          final date = DateTime.parse(h['assessment_date']);
          final val = h['weight']?.toDouble() ?? 0.0;
          return ChartPoint(date: date, value: val);
        })
        .where((p) => p.value > 0)
        .toList();

    if (points.length < 2) return const SizedBox.shrink();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Histórico de Peso',
            style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: SimpleLineChartPainter(
                points: points,
                lineColor: const Color(0xFF457B9D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildMeasureRow('Pescoço', report['neck']),
          _buildMeasureRow('Peitoral', report['chest']),
          _buildMeasureRow('Cintura', report['waist']),
          _buildMeasureRow('Abdômen', report['abdomen']),
          _buildMeasureRow('Quadril', report['hips']),
          const Divider(height: 24),
          _buildMeasureRow('Braço Dir.', report['right_arm']),
          _buildMeasureRow('Braço Esq.', report['left_arm']),
          const Divider(height: 24),
          _buildMeasureRow('Coxa Dir.', report['right_thigh']),
          _buildMeasureRow('Coxa Esq.', report['left_thigh']),
          const Divider(height: 24),
          _buildMeasureRow('Panturrilha Dir.', report['right_calf']),
          _buildMeasureRow('Panturrilha Esq.', report['left_calf']),
        ],
      ),
    );
  }

  Widget _buildMeasureRow(String label, dynamic value) {
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
            '${value.toString()} cm',
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
    minVal -= range * 0.1;
    maxVal += range * 0.1;
    range = maxVal - minVal;

    final w = size.width;
    final h = size.height;

    // Draw Grid (3 lines)
    for (int i = 0; i <= 2; i++) {
      final y = h - (h * (i / 2));
      canvas.drawLine(Offset(0, y), Offset(w, y), axisPaint);
    }

    // path
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * w;
      final normalizedVal = (points[i].value - minVal) / range;
      final y = h - (normalizedVal * h);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Draw dot
      final dotPaint = Paint()..color = lineColor;
      canvas.drawCircle(Offset(x, y), 4, dotPaint);

      // Draw dot center
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
