import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/trainer_schedule_service.dart';
import '../../../config/app_theme.dart';

class EditSessionScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const EditSessionScreen({super.key, required this.session});

  @override
  State<EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<EditSessionScreen> {
  bool _isSaving = false;

  late String _studentId;
  late String _studentName;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  final _notesController = TextEditingController();

  Map<String, dynamic>? _workoutPreview;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    final s = widget.session;
    _studentId = s['student_id'];
    _studentName = s['users_alunos']?['nome'] ?? 'Aluno';
    final dt = DateTime.parse(s['scheduled_at']).toLocal();
    _selectedDate = dt;
    _selectedTime = TimeOfDay.fromDateTime(dt);
    _notesController.text = s['notes'] ?? '';

    _checkWorkoutDay();
  }

  Future<void> _checkWorkoutDay() async {
    try {
      final result = await TrainerScheduleService.getWorkoutForDate(
        _studentId,
        _selectedDate,
      );
      if (mounted) {
        setState(() {
          _workoutPreview = result;
        });
      }
    } catch (e) {
      // Ignore errors fetching preview
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Using Supabase instance directly
      await Supabase.instance.client.from('training_sessions').update({
        'scheduled_at': scheduledAt.toIso8601String(),
        'notes': _notesController.text,
      }).eq('id', widget.session['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agendamento atualizado!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e')),
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
          'Editar Agendamento',
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
            // Read-only Student Info
            Text('Aluno',
                style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryText)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _studentName,
                style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[700]),
              ),
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
                            firstDate: DateTime(2024),
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

            const SizedBox(height: 24),

            // Status Treino do Dia
            if (_workoutPreview != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _workoutPreview!['day_name'] != null
                      ? Colors.green[50]
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _workoutPreview!['day_name'] != null
                          ? Colors.green[200]!
                          : Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                        _workoutPreview!['day_name'] != null
                            ? Icons.check_circle
                            : Icons.warning_amber,
                        color: _workoutPreview!['day_name'] != null
                            ? Colors.green
                            : Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _workoutPreview!['day_name'] != null
                            ? 'Treino Configurado: ${_workoutPreview!['day_name']}'
                            : 'Atenção: Nenhum treino específico na ficha para este dia da semana.',
                        style: TextStyle(
                          color: _workoutPreview!['day_name'] != null
                              ? Colors.green[800]
                              : Colors.orange[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Observações',
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
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SALVAR ALTERAÇÕES',
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
    );
  }
}
