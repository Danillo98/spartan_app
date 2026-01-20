import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/trainer_schedule_service.dart';
import '../../../config/app_theme.dart';

class SessionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _workoutDetails;

  @override
  void initState() {
    super.initState();
    _loadWorkoutDetails();
  }

  Future<void> _loadWorkoutDetails() async {
    try {
      final studentId = widget.session['student_id'];
      final date = DateTime.parse(widget.session['scheduled_at']);

      final details =
          await TrainerScheduleService.getWorkoutForDate(studentId, date);

      if (mounted) {
        setState(() {
          _workoutDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(widget.session['scheduled_at']).toLocal();
    final studentName = widget.session['users_alunos']?['nome'] ?? 'Aluno';

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          'Detalhes do Treino',
          style: GoogleFonts.cinzel(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryText,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryRed.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person,
                        size: 32, color: AppTheme.primaryRed),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: GoogleFonts.lato(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(date)} às ${DateFormat('HH:mm').format(date)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Workout Details
            if (_isLoading)
              const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryRed))
            else if (_workoutDetails == null ||
                _workoutDetails!['day_name'] == null)
              _buildEmptyState()
            else
              _buildWorkoutContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.fitness_center_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Nenhum treino específico encontrado para este dia.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutContent() {
    final exercises = _workoutDetails!['exercises'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _workoutDetails!['day_name'],
              style: GoogleFonts.lato(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryText,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _workoutDetails!['workout_name'] ?? 'Ficha',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final exercise = exercises[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vertical Bar
                  Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise['exercise_name'] ?? 'Exercício Sem Nome',
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildInfoTag(Icons.repeat_rounded,
                                '${exercise['sets']} x ${exercise['reps']}'),
                            if (exercise['weight_kg'] != null &&
                                exercise['weight_kg'] > 0)
                              _buildInfoTag(Icons.fitness_center_rounded,
                                  '${exercise['weight_kg']} kg'),
                            if (exercise['rest_seconds'] != null &&
                                exercise['rest_seconds'] > 0)
                              _buildInfoTag(Icons.timer_outlined,
                                  '${exercise['rest_seconds']}s desc'),
                            if (exercise['technique'] != null &&
                                exercise['technique'].toString().isNotEmpty)
                              _buildInfoTag(Icons.lightbulb_outline,
                                  exercise['technique'],
                                  isHighlight: true),
                          ],
                        ),
                        if (exercise['notes'] != null &&
                            exercise['notes'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Obs: ${exercise['notes']}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfoTag(IconData icon, String text, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.orange[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isHighlight ? Colors.orange[200]! : Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: isHighlight ? Colors.orange[800] : Colors.grey[700]),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: isHighlight ? Colors.orange[900] : Colors.grey[800],
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
