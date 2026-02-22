import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import 'assessment_list_screen.dart';
import '../nutritionist/reports/reports_list_screen.dart';

class AdminAssessmentChooserScreen extends StatelessWidget {
  const AdminAssessmentChooserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          'Avaliações Físicas',
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildModernChooserCard(
                context: context,
                title: 'Avaliações Agendadas',
                icon: Icons.calendar_month_rounded,
                color: const Color(0xFFE65100),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AssessmentListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildModernChooserCard(
                context: context,
                title: 'Avaliações Realizadas',
                icon: Icons.assignment_turned_in_rounded,
                color: const Color(0xFF2E7D32),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReportsListScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernChooserCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(40),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: color.withAlpha(20), width: 1),
        ),
        child: Row(
          children: [
            const SizedBox(width: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}
