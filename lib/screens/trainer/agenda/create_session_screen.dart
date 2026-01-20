import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/user_service.dart';
import '../../../services/trainer_schedule_service.dart';
import '../../../config/app_theme.dart';
import '../../../widgets/searchable_selection.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  // Data
  List<Map<String, dynamic>> _students = [];
  String? _selectedStudentId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final _notesController = TextEditingController();

  // Preview do Treino
  bool _checkingWorkout = false;
  Map<String, dynamic>? _workoutPreview;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await UserService.getStudentsForStaff();
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Triggered when Student or Date changes
  Future<void> _checkWorkoutDay() async {
    if (_selectedStudentId == null) return;

    setState(() => _checkingWorkout = true);
    try {
      final result = await TrainerScheduleService.getWorkoutForDate(
        _selectedStudentId!,
        _selectedDate,
      );
      if (mounted) {
        setState(() {
          _workoutPreview = result;
          _checkingWorkout = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _checkingWorkout = false);
    }
  }

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um aluno')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Combine Date + Time
      final scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await TrainerScheduleService.createSession(
        studentId: _selectedStudentId!,
        scheduledAt: scheduledAt,
        notes: _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Treino agendado com sucesso!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao agendar: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          'Agendar Treino',
          style: GoogleFonts.cinzel(
              fontWeight: FontWeight.bold, color: AppTheme.primaryText),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown de Aluno com Pesquisa
                    SearchableSelection<Map<String, dynamic>>(
                      label: 'Aluno',
                      value: _selectedStudentId != null
                          ? _students.firstWhere(
                              (s) => s['id'] == _selectedStudentId,
                              orElse: () => {})
                          : null,
                      items: _students,
                      labelBuilder: (student) => student['name'] ?? 'Sem Nome',
                      hintText: 'Selecione o aluno',
                      onChanged: (studentKey) {
                        if (studentKey != null) {
                          setState(() => _selectedStudentId = studentKey['id']);
                          _checkWorkoutDay();
                        }
                      },
                      isLoading: _isLoading,
                    ),

                    const SizedBox(height: 24),

                    // Date & Time Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Data',
                                  style: GoogleFonts.lato(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondaryText)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2030),
                                    builder: (context, child) {
                                      return Theme(
                                        data: ThemeData.light().copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: AppTheme.primaryRed,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (d != null) {
                                    setState(() => _selectedDate = d);
                                    _checkWorkoutDay();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightGrey,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded,
                                          size: 18, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(DateFormat('dd/MM/yyyy')
                                          .format(_selectedDate)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hora',
                                  style: GoogleFonts.lato(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondaryText)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTime,
                                    builder: (context, child) {
                                      return Theme(
                                        data: ThemeData.light().copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: AppTheme.primaryRed,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (t != null) {
                                    setState(() => _selectedTime = t);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightGrey,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded,
                                          size: 18, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(_selectedTime.format(context)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Workout Preview Card
                    if (_selectedStudentId != null)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _workoutPreview != null &&
                                  _workoutPreview!['day_name'] != null
                              ? Colors.green[50]
                              : Colors.orange[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _workoutPreview != null &&
                                      _workoutPreview!['day_name'] != null
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.orange.withOpacity(0.3)),
                        ),
                        child: _checkingWorkout
                            ? const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _workoutPreview != null &&
                                                _workoutPreview!['day_name'] !=
                                                    null
                                            ? Icons.check_circle_outline
                                            : Icons.warning_amber_rounded,
                                        color: _workoutPreview != null &&
                                                _workoutPreview!['day_name'] !=
                                                    null
                                            ? Colors.green[700]
                                            : Colors.orange[800],
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Treino Previsto',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _workoutPreview != null &&
                                                  _workoutPreview![
                                                          'day_name'] !=
                                                      null
                                              ? Colors.green[900]
                                              : Colors.orange[900],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (_workoutPreview == null)
                                    const Text(
                                        'Este aluno não possui ficha ativa.')
                                  else if (_workoutPreview!['day_name'] == null)
                                    Text(
                                        'O aluno tem a ficha "${_workoutPreview!['workout_name']}", mas não há treino configurado para ${DateFormat('EEEE', 'pt_BR').format(_selectedDate)}.')
                                  else
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Ficha: ${_workoutPreview!['workout_name']}'),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Treino do Dia: ${_workoutPreview!['day_name']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        const SizedBox(height: 12),
                                        Column(
                                          children:
                                              (_workoutPreview!['exercises']
                                                      as List)
                                                  .map((exercise) {
                                            return Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 12),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 3,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primaryRed
                                                          .withOpacity(0.5),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              2),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          exercise[
                                                                  'exercise_name'] ??
                                                              'Exercício',
                                                          style:
                                                              GoogleFonts.lato(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 15,
                                                            color: AppTheme
                                                                .primaryText,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 2),
                                                        Text(
                                                          '${exercise['sets']} séries x ${exercise['reps']} reps' +
                                                              (exercise['weight_kg'] !=
                                                                          null &&
                                                                      exercise['weight_kg']
                                                                              .toString() !=
                                                                          '0'
                                                                  ? ' | ${exercise['weight_kg']}kg'
                                                                  : '') +
                                                              (exercise['duration'] !=
                                                                          null &&
                                                                      exercise[
                                                                              'duration']
                                                                          .toString()
                                                                          .isNotEmpty
                                                                  ? ' | ${exercise['duration']}'
                                                                  : ''),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                      ),

                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Observações (Opcional)',
                        filled: true,
                        fillColor: AppTheme.lightGrey,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'CONFIRMAR AGENDAMENTO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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
}
