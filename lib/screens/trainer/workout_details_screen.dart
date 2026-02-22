import 'dart:async';
import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/workout_service.dart';
import '../../services/cache_manager.dart';
import '../../config/app_theme.dart';
import 'add_workout_exercise_screen.dart';
import 'edit_workout_day_screen.dart';
import 'edit_workout_exercise_screen.dart';
import 'edit_workout_screen.dart';

class WorkoutDetailsScreen extends StatefulWidget {
  final String workoutId;
  final String workoutName;

  const WorkoutDetailsScreen({
    super.key,
    required this.workoutId,
    required this.workoutName,
  });

  @override
  State<WorkoutDetailsScreen> createState() => _WorkoutDetailsScreenState();
}

class _WorkoutDetailsScreenState extends State<WorkoutDetailsScreen> {
  bool _isLoading = true;
  bool _isPrinting = false;
  Map<String, dynamic>? _workout;
  String? _errorMessage;
  static const trainerPrimary = AppTheme.primaryRed;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await WorkoutService.getWorkoutById(widget.workoutId)
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _workout = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ERRO AO CARREGAR TREINO: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.lightGrey,
          appBar: AppBar(
            backgroundColor: trainerPrimary,
            title: Text(
              widget.workoutName,
              style: GoogleFonts.lato(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: trainerPrimary))
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: AppTheme.accentRed),
                            const SizedBox(height: 16),
                            Text(
                              'Erro ao carregar',
                              style: GoogleFonts.lato(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: GoogleFonts.lato(
                                  fontSize: 14, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadDetails,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar Novamente'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: trainerPrimary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _workout == null
                      ? const Center(child: Text('Treino não encontrado'))
                      : RefreshIndicator(
                          onRefresh: _loadDetails,
                          color: trainerPrimary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeaderCard(),
                                const SizedBox(height: 24),
                                _buildDaysSection(),
                              ],
                            ),
                          ),
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
                      CircularProgressIndicator(color: trainerPrimary),
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

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: trainerPrimary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: trainerPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Visão Geral',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Colors.blueGrey),
                      onPressed: _editWorkout,
                      tooltip: 'Editar Ficha',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.print_rounded,
                    size: 20, color: trainerPrimary),
                onPressed: _openPrintPage,
                tooltip: 'Imprimir Ficha',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_workout!['student'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    _workout!['student']['name'] ?? 'Aluno sem nome',
                    style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
            ),
          _buildDescriptionWithImages(
              _workout!['description'] ?? 'Sem descrição'),
        ],
      ),
    );
  }

  Future<void> _editWorkout() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditWorkoutScreen(workout: _workout!),
      ),
    );

    if (result == true) {
      // Forçar limpeza do cache para este treino para garantir que os dados novos apareçam
      await CacheManager()
          .invalidatePattern('workout_detail_${widget.workoutId}');

      // Forçar refresh visual setando loading
      if (mounted) {
        // Limpar cache ao abrir para garantir dados frescos e com nome do personal
        if (widget.workoutId != null) {
          await CacheManager()
              .invalidate(CacheKeys.workoutDetail(widget.workoutId!));
        }
      }

      await _loadDetails();
    }
  }

  Future<void> _openPrintPage() async {
    if (_workout == null) return;
    setState(() => _isPrinting = true);

    try {
      final printData = {
        'name': _workout!['name'] ?? widget.workoutName,
        'description': _workout!['description'],
        'student_name': _workout!['student']?['name'] ??
            _workout!['student']?['nome'] ??
            'Aluno',
        'personal_name': _workout!['personal']?['name'] ??
            _workout!['personal']?['nome'] ??
            _workout!['personal']?['full_name'] ??
            'Instrutor Spartan',
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

      print('🖨️ Enviando para PDF: $printData');

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

  Widget _buildDescriptionWithImages(String description) {
    if (!description.contains('[IMG_BASE64:')) {
      return Text(
        description,
        style: GoogleFonts.lato(
          fontSize: 14,
          color: AppTheme.secondaryText,
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
            fontSize: 14,
            color: AppTheme.secondaryText,
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
          fontSize: 14,
          color: AppTheme.secondaryText,
          height: 1.5,
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildDaysSection() {
    final days = (_workout!['days'] as List?) ?? [];
    final hasDescription = _workout!['description'] != null &&
        _workout!['description'].toString().trim().isNotEmpty;

    if (days.isEmpty && hasDescription) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Roteiro de Treinos',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText,
              ),
            ),
            TextButton.icon(
              onPressed: _navigateToAddDay,
              icon: const Icon(Icons.add, size: 18, color: trainerPrimary),
              label: Text(
                'Adicionar Dia',
                style: GoogleFonts.lato(
                  color: trainerPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: trainerPrimary.withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (days.isEmpty)
          (_buildEmptyDaysState())
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final day = days[index];
              return _buildDayCard(day);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyDaysState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Nenhum dia configurado',
              style: GoogleFonts.lato(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Comece adicionando "Treino A", "Segunda", etc.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final exercises = (day['exercises'] as List?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          title: Text(
            day['day_name'] ?? 'Dia sem nome',
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          subtitle: day['description'] != null
              ? Text(
                  day['description'],
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: trainerPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 20, color: Colors.blueGrey),
                onPressed: () => _editDay(day),
                tooltip: 'Editar Dia',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppTheme.accentRed),
                onPressed: () => _confirmDeleteDay(day),
                tooltip: 'Excluir Dia',
              ),
              IconButton(
                icon:
                    const Icon(Icons.add_circle_outline, color: trainerPrimary),
                onPressed: () => _navigateToAddExercise(day['id']),
                tooltip: 'Adicionar Exercício',
              ),
            ],
          ),
          children: [
            if (exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Nenhum exercício adicionado.',
                  style: GoogleFonts.lato(fontSize: 13, color: Colors.grey),
                ),
              )
            else
              Column(
                children: exercises
                    .map<Widget>((ex) => _buildExerciseItem(ex))
                    .toList(),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editDay(Map<String, dynamic> day) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditWorkoutDayScreen(
          dayId: day['id'],
          currentName: day['day_name'],
          currentDescription: day['description'],
        ),
      ),
    );

    if (result == true) {
      _loadDetails();
    }
  }

  void _confirmDeleteDay(Map<String, dynamic> day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir Dia?',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: Text(
            'Deseja excluir "${day['day_name']}" e todos os seus exercícios?',
            style: GoogleFonts.lato()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Fechar dialog
              await _deleteDay(day['id']);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDay(String dayId) async {
    setState(() => _isLoading = true);
    final result = await WorkoutService.deleteWorkoutDay(dayId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor:
              result['success'] ? trainerPrimary : AppTheme.accentRed,
        ),
      );
      if (result['success']) {
        _loadDetails();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildExerciseItem(Map<String, dynamic> exercise) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: trainerPrimary.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['exercise_name'] ?? 'Exercício',
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildDetailText('${exercise['sets']} séries'),
                    _buildDetailText('x'),
                    _buildDetailText('${exercise['reps']} reps'),
                    if (exercise['weight_kg'] != null &&
                        exercise['weight_kg'] > 0) ...[
                      _buildDetailText('|'),
                      _buildDetailText('${exercise['weight_kg']}kg'),
                    ],
                  ],
                ),
                if (exercise['notes'] != null &&
                    exercise['notes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Nota: ${exercise['notes']}',
                      style: GoogleFonts.lato(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          // Actions Row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _editExercise(exercise),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.edit_outlined,
                      size: 18, color: Colors.blueGrey[400]),
                ),
              ),
              InkWell(
                onTap: () => _confirmDeleteExercise(exercise),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.accentRed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editExercise(Map<String, dynamic> exercise) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditWorkoutExerciseScreen(exercise: exercise),
      ),
    );

    if (result == true) {
      _loadDetails();
    }
  }

  void _confirmDeleteExercise(Map<String, dynamic> exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir Exercício?',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: Text('Deseja excluir "${exercise['exercise_name']}"?',
            style: GoogleFonts.lato()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _deleteExercise(exercise['id']);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExercise(String exerciseId) async {
    setState(() => _isLoading = true);
    try {
      await WorkoutService.deleteExercise(exerciseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exercício excluído com sucesso'),
            backgroundColor: trainerPrimary,
          ),
        );
        _loadDetails();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Widget _buildDetailText(String text) {
    return Text(
      text,
      style: GoogleFonts.lato(
        fontSize: 13,
        color: Colors.grey[700],
      ),
    );
  }

  void _navigateToAddDay() {
    final days = (_workout!['days'] as List?) ?? [];
    final usedDayNames = days.map((d) => d['day_name'] as String).toSet();

    final availableDays = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo'
    ].where((day) => !usedDayNames.contains(day)).toList();

    if (availableDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos os dias da semana já foram configurados'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Adicionar Dia de Treino',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableDays.map((dayName) {
              return ListTile(
                leading:
                    const Icon(Icons.calendar_today, color: trainerPrimary),
                title: Text(dayName, style: GoogleFonts.lato()),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _showConfigureDayDialog(dayName);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _showConfigureDayDialog(String dayName) {
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Configurar $dayName',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descrição do Treino',
                  hintText: 'Ex: Treino de peito e tríceps...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon:
                      const Icon(Icons.description, color: trainerPrimary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Você poderá adicionar exercícios após salvar o dia',
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _addNewDay(dayName, descriptionController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: trainerPrimary),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewDay(String dayName, String description) async {
    setState(() => _isLoading = true);

    try {
      final days = (_workout!['days'] as List?) ?? [];
      final nextDayNumber = days.length + 1;

      await WorkoutService.addWorkoutDay(
        workoutId: widget.workoutId,
        dayName: dayName,
        dayNumber: nextDayNumber,
        description: description.isEmpty ? 'Treino de $dayName' : description,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dia adicionado com sucesso!'),
            backgroundColor: trainerPrimary,
          ),
        );
        _loadDetails();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar dia: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _navigateToAddExercise(String dayId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddWorkoutExerciseScreen(workoutDayId: dayId),
      ),
    );

    if (result == true) {
      _loadDetails();
    }
  }
}
