import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/workout_service.dart';
import '../../services/auth_service.dart';
import '../../services/workout_session_service.dart';
import '../../config/app_theme.dart';

class MyWorkoutScreen extends StatefulWidget {
  const MyWorkoutScreen({super.key});

  @override
  State<MyWorkoutScreen> createState() => _MyWorkoutScreenState();
}

class _MyWorkoutScreenState extends State<MyWorkoutScreen> {
  List<Map<String, dynamic>> _workouts = [];
  bool _isLoading = true;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    if (_workouts.isEmpty) setState(() => _isLoading = true);
    try {
      final userData = await AuthService.getCurrentUserData();
      _studentId = userData?['id'];

      if (_studentId != null) {
        final workouts = await WorkoutService.getWorkoutsByStudent(_studentId!);
        if (mounted) {
          setState(() {
            _workouts = workouts;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar treinos: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Se já deu pop, não faz nada. Caso contrário (embora canPop seja true),
        // garantimos que o comportamento seja o esperado de voltar.
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryRed,
          title: Text(
            'Meus Treinos',
            style: GoogleFonts.lato(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryRed),
              )
            : _workouts.isEmpty
                ? _buildEmptyState()
                : _buildWorkoutsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                size: 64,
                color: AppTheme.primaryRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhum treino cadastrado',
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Seu personal trainer ainda não criou um treino para você.',
              style: GoogleFonts.lato(
                fontSize: 14,
                color: AppTheme.secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workouts.length,
      itemBuilder: (context, index) {
        final workout = _workouts[index];
        return _buildWorkoutCard(workout);
      },
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final isActive = workout['is_active'] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkoutDetailsStudentScreen(
                workoutId: workout['id'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workout['name'] ?? 'Sem nome',
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                  ),
                  _buildStatusBadge(isActive),
                ],
              ),
              if (workout['description'] != null) ...[
                Builder(
                  builder: (context) {
                    final cleanDesc = workout['description']
                        .toString()
                        .replaceAll(RegExp(r'\[IMG_BASE64:[^\]]+\]'), '')
                        .trim();
                    if (cleanDesc.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          cleanDesc,
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: AppTheme.secondaryText,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (workout['goal'] != null) ...[
                    _buildInfoChip(
                      Icons.flag_rounded,
                      workout['goal'],
                      AppTheme.primaryRed,
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (workout['difficulty_level'] != null)
                    _buildInfoChip(
                      Icons.speed_rounded,
                      workout['difficulty_level'],
                      const Color(0xFFFFA726),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppTheme.secondaryText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Personal: ${workout['personal']?['name'] ?? 'Não informado'}',
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF4CAF50).withOpacity(0.1)
            : const Color(0xFF757575).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : const Color(0xFF757575).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            size: 14,
            color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF757575),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Ativo' : 'Pausado',
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color:
                  isActive ? const Color(0xFF4CAF50) : const Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Tela de detalhes do treino para o aluno
class WorkoutDetailsStudentScreen extends StatefulWidget {
  final String workoutId;

  const WorkoutDetailsStudentScreen({
    super.key,
    required this.workoutId,
  });

  @override
  State<WorkoutDetailsStudentScreen> createState() =>
      _WorkoutDetailsStudentScreenState();
}

class _WorkoutDetailsStudentScreenState
    extends State<WorkoutDetailsStudentScreen> {
  Map<String, dynamic>? _workout;
  bool _isLoading = true;
  bool _isPrinting = false;
  final Set<String> _completedExercises = {};

  @override
  void initState() {
    super.initState();
    // Carregar estado persistente da sessão
    _completedExercises
        .addAll(WorkoutSessionService.getCompletedExercises(widget.workoutId));
    _loadWorkout();
  }

  void _toggleExercise(String? id) {
    if (id == null) return;
    setState(() {
      WorkoutSessionService.toggleExercise(widget.workoutId, id);
      // Atualizar set local para refletir na UI imediatamente
      if (_completedExercises.contains(id)) {
        _completedExercises.remove(id);
      } else {
        _completedExercises.add(id);
        _checkDayCompletion(id);
      }
    });
  }

  void _checkDayCompletion(String exerciseId) {
    final days = (_workout!['days'] as List?) ?? [];
    for (var day in days) {
      final exercises = (day['exercises'] as List?) ?? [];
      final hasExercise = exercises.any((e) => e['id'] == exerciseId);

      if (hasExercise) {
        final allCompleted =
            exercises.every((e) => _completedExercises.contains(e['id']));

        if (allCompleted) {
          _showCelebrationDialog(day['day_name']);
        }
        break;
      }
    }
  }

  void _showCelebrationDialog(String dayName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icone Festivo com Glow
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 10,
                    )
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 64,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 24),

              // Título
              Text(
                'TREINO CONCLUÍDO!',
                style: GoogleFonts.cinzel(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Descrição
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    color: AppTheme.secondaryText,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                        text:
                            'Parabéns, espartano! Você destruiu o treino de '),
                    TextSpan(
                      text: dayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const TextSpan(
                        text: ' hoje.\nContinue focado no objetivo!'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Botão Continuar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    'CONTINUAR',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadWorkout() async {
    setState(() => _isLoading = true);
    try {
      final workout = await WorkoutService.getWorkoutById(widget.workoutId);
      if (workout != null) {
        setState(() {
          _workout = workout;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Treino não encontrado'),
              backgroundColor: AppTheme.accentRed,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar treino: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _openPrintPage() async {
    if (_workout == null) return;
    setState(() => _isPrinting = true);

    try {
      final printData = {
        'name': _workout!['name'] ?? 'Treino',
        'description': _workout!['description'],
        'student_name': _workout!['student']?['name'],
        'personal_name': _workout!['personal']?['name'] ?? 'N/A',
        'goal': _workout!['goal'],
        'difficulty_level': _workout!['difficulty_level'],
        'start_date': _workout!['start_date'],
        'end_date': _workout!['end_date'],
        'days': _workout!['days'],
      };

      final jsonData = jsonEncode(printData);
      final blob = html.Blob([jsonData], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final baseUrl = html.window.location.origin;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final printUrl = '$baseUrl/print-workout.html?v=$timestamp&dataUrl=$url';

      if (mounted) setState(() => _isPrinting = false);

      html.window.open(printUrl, '_blank');

      Future.delayed(const Duration(seconds: 20), () {
        html.Url.revokeObjectUrl(url);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir impressão: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.lightGrey,
          body: _isLoading ? _buildLoading() : _buildBody(),
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
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.primaryRed),
    );
  }

  Widget _buildDescriptionWithImages(String description) {
    if (!description.contains('[IMG_BASE64:')) {
      return Text(
        description,
        style: GoogleFonts.lato(
          fontSize: 15,
          color: AppTheme.primaryText,
          height: 1.5,
        ),
      );
    }

    final RegExp exp = RegExp(r'\[IMG_BASE64:(.*?)\]');
    final Iterable<RegExpMatch> matches = exp.allMatches(description);

    int lastEnd = 0;
    List<Widget> children = [];

    for (final match in matches) {
      if (match.start > lastEnd) {
        children.add(Text(
          description.substring(lastEnd, match.start).trimRight(),
          style: GoogleFonts.lato(
            fontSize: 15,
            color: AppTheme.primaryText,
            height: 1.5,
          ),
        ));
      }

      final base64String = match.group(1);
      if (base64String != null && base64String.isNotEmpty) {
        try {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(base64String),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        } catch (e) {
          // ignore
        }
      }

      lastEnd = match.end;
    }

    if (lastEnd < description.length) {
      children.add(Text(
        description.substring(lastEnd).trimLeft(),
        style: GoogleFonts.lato(
          fontSize: 15,
          color: AppTheme.primaryText,
          height: 1.5,
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildBody() {
    if (_workout == null) {
      return const Center(child: Text('Treino não encontrado'));
    }

    final days = (_workout!['days'] as List?) ?? [];
    final sortedDays = WorkoutService.sortDays(days);
    final hasDescription = _workout!['description'] != null &&
        _workout!['description'].toString().trim().isNotEmpty;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        SliverToBoxAdapter(child: _buildWorkoutInfo()),
        if (sortedDays.isEmpty && !hasDescription)
          SliverFillRemaining(child: _buildEmptyDays())
        else if (sortedDays.isNotEmpty)
          SliverToBoxAdapter(child: _buildDaysSection(sortedDays)),
      ],
    );
  }

  Widget _buildSliverAppBar() {
    final isActive = _workout!['is_active'] ?? true;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryRed, Color(0xFFB71C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _workout!['name'] ?? 'Sem nome',
                    style: GoogleFonts.lato(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusBadge(isActive),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_pin_rounded,
                        size: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Personal: ${_workout!['personal']?['name'] ?? 'Não atribuído'}',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.print_rounded, color: Colors.white),
          onPressed: _openPrintPage,
          tooltip: 'Imprimir Treino',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Ativo' : 'Pausado',
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_workout!['description'] != null &&
              _workout!['description'].toString().isNotEmpty) ...[
            Text(
              'Descrição',
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            _buildDescriptionWithImages(_workout!['description']),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              if (_workout!['goal'] != null)
                Expanded(
                  child: _buildInfoItem(
                    Icons.flag_rounded,
                    'Objetivo',
                    _workout!['goal'],
                    AppTheme.primaryRed,
                  ),
                ),
              if (_workout!['goal'] != null &&
                  _workout!['difficulty_level'] != null)
                const SizedBox(width: 12),
              if (_workout!['difficulty_level'] != null)
                Expanded(
                  child: _buildInfoItem(
                    Icons.speed_rounded,
                    'Nível',
                    _workout!['difficulty_level'],
                    const Color(0xFFFFA726),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSection(List days) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.calendar_view_week_rounded,
                    color: AppTheme.primaryRed),
                const SizedBox(width: 12),
                Text(
                  'Dias de Treino',
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
                const Spacer(),
                Text(
                  '${days.length} ${days.length == 1 ? 'dia' : 'dias'}',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final day = days[index];
              return _buildDayItem(day);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayItem(Map<String, dynamic> day) {
    final exercises = (day['exercises'] as List?) ?? [];

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryRed.withOpacity(0.1),
        child: Text(
          day['day_letter'] ?? '${day['day_number'] ?? '?'}',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryRed,
          ),
        ),
      ),
      title: Text(
        day['day_name'] ?? 'Dia sem nome',
        style: GoogleFonts.lato(
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryText,
        ),
      ),
      subtitle: Text(
        '${exercises.length} ${exercises.length == 1 ? 'exercício' : 'exercícios'}',
        style: GoogleFonts.lato(
          fontSize: 13,
          color: AppTheme.secondaryText,
        ),
      ),
      children: [
        if (exercises.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDayProgressBar(day, exercises),
                const SizedBox(height: 8),
              ],
            ),
          ),
        if (exercises.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  size: 48,
                  color: AppTheme.secondaryText.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nenhum exercício cadastrado',
                  style: GoogleFonts.lato(
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          )
        else
          ...exercises
              .map<Widget>((exercise) => _buildExerciseItem(exercise))
              .toList(),
      ],
    );
  }

  Widget _buildDayProgressBar(
      Map<String, dynamic> day, List<dynamic> exercises) {
    int total = exercises.length;
    int completed =
        exercises.where((e) => _completedExercises.contains(e['id'])).length;
    double progress = total == 0 ? 0 : completed / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progresso do Dia',
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryText,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: progress == 1.0 ? Colors.green : AppTheme.primaryRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? Colors.green : AppTheme.primaryRed,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseItem(Map<String, dynamic> exercise) {
    final isCompleted = _completedExercises.contains(exercise['id']);

    return InkWell(
      onTap: () => _toggleExercise(exercise['id']),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isCompleted ? Colors.green.withOpacity(0.05) : AppTheme.lightGrey,
          borderRadius: BorderRadius.circular(12),
          border: isCompleted
              ? Border.all(color: Colors.green.withOpacity(0.3))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha do Cabeçalho: Checkbox + Título
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Checkbox
                      InkWell(
                        onTap: () => _toggleExercise(exercise['id']),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(top: 2, right: 12),
                          decoration: BoxDecoration(
                            color:
                                isCompleted ? Colors.green : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCompleted
                                  ? Colors.green
                                  : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                          child: isCompleted
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                      // Título
                      Expanded(
                        child: Text(
                          exercise['exercise_name'] ?? 'Sem nome',
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCompleted
                                ? Colors.green[800]
                                : AppTheme.primaryText,
                            decoration:
                                isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Detalhes (Chips) - Agora alinhados com o início do card (esquerda)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildExerciseChip(
                            'Séries',
                            '${exercise['sets'] ?? 0}',
                            const Color(0xFF4CAF50),
                          ),
                          const SizedBox(width: 8),
                          _buildExerciseChip(
                            'Reps',
                            exercise['reps'] ?? '-',
                            const Color(0xFF2196F3),
                          ),
                        ],
                      ),
                      if (exercise['weight_kg'] != null ||
                          exercise['rest_seconds'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (exercise['weight_kg'] != null) ...[
                                _buildExerciseChip(
                                  'Peso',
                                  '${exercise['weight_kg']}kg',
                                  const Color(0xFFFFA726),
                                ),
                                if (exercise['rest_seconds'] != null)
                                  const SizedBox(width: 8),
                              ],
                              if (exercise['rest_seconds'] != null)
                                _buildExerciseChip(
                                  'Descanso',
                                  '${exercise['rest_seconds']}s',
                                  const Color(0xFF9C27B0),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Técnica e Observações
                  if (exercise['technique'] != null ||
                      exercise['notes'] != null) ...[
                    const SizedBox(height: 12),
                    if (exercise['technique'] != null) ...[
                      Text(
                        'Técnica:',
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exercise['technique'],
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: AppTheme.primaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (exercise['notes'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Observações:',
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exercise['notes'],
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: AppTheme.primaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // Imagem do Grupo Muscular
            if (exercise['muscle_group'] != null) ...[
              const SizedBox(width: 16),
              _buildMuscleGroupIcon(exercise['muscle_group']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleGroupIcon(String group) {
    const Map<String, String> muscleImages = {
      'Peito': 'assets/images/muscle_chest.png',
      'Costas': 'assets/images/muscle_back.png',
      'Ombros': 'assets/images/muscle_shoulders.png',
      'Bíceps': 'assets/images/muscle_biceps.png',
      'Tríceps': 'assets/images/muscle_triceps.png',
      'Quadríceps': 'assets/images/muscle_quadriceps.png',
      'Posterior': 'assets/images/muscle_hamstrings.png',
      'Glúteos': 'assets/images/muscle_glutes.png',
      'Panturrilhas': 'assets/images/muscle_calves.png',
      'Abdômen': 'assets/images/muscle_abs.png',
      'Cardio': 'assets/images/muscle_cardio.png',
      'Funcional': 'assets/images/muscle_functional.png',
    };

    final assetPath = muscleImages[group];

    if (assetPath == null) return const SizedBox.shrink();

    return Container(
      width: 100,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildExerciseChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDays() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 64,
              color: AppTheme.secondaryText.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum dia cadastrado',
              style: GoogleFonts.lato(
                fontSize: 16,
                color: AppTheme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
