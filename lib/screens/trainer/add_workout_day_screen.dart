import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../services/workout_service.dart';

class AddWorkoutDayScreen extends StatefulWidget {
  final String workoutId;

  const AddWorkoutDayScreen({super.key, required this.workoutId});

  @override
  State<AddWorkoutDayScreen> createState() => _AddWorkoutDayScreenState();
}

class _AddWorkoutDayScreenState extends State<AddWorkoutDayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController =
      TextEditingController(); // Description is now main focus
  String? _selectedDayLetter;
  bool _isLoading = false;

  // Days of the week presets
  final List<String> _weekDays = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
    'Treino A',
    'Treino B',
    'Treino C',
    'Treino D',
    'Treino E',
  ];

  static const trainerPrimary = AppTheme.primaryRed;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveDay() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Find the next day number (just auto-increment or similar if needed,
      // but here we might not rely on order strictly or backend handles it via order_index if implemented,
      // creating with a high number or current timestamp based is fine for now, or fetch existing count)
      // For simplicity, we just pass 0 or random for now as user orders by name often visually.
      // But let's check existing logic. WorkoutService.addWorkoutDay needs dayNumber.
      // We will assume 0 for now as sorting might be by name or letter.

      final result = await WorkoutService.addWorkoutDay(
        workoutId: widget.workoutId,
        dayName: _nameController.text,
        dayNumber: DateTime.now()
            .millisecondsSinceEpoch, // temporary Unique ID for sort if needed
        dayLetter: _selectedDayLetter,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
      );

      if (mounted) {
        if (result['success']) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar dia: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Adicionar Dia de Treino',
          style: GoogleFonts.lato(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: trainerPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Identificação do Dia',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              const SizedBox(height: 16),

              // Preset Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _weekDays
                    .map((day) => ActionChip(
                          label: Text(day),
                          backgroundColor: _nameController.text == day
                              ? trainerPrimary.withOpacity(0.1)
                              : Colors.grey[100],
                          labelStyle: GoogleFonts.lato(
                            color: _nameController.text == day
                                ? trainerPrimary
                                : Colors.black87,
                            fontWeight: _nameController.text == day
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onPressed: () {
                            setState(() {
                              _nameController.text = day;
                            });
                          },
                        ))
                    .toList(),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome do Dia (ex: Segunda-feira)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon:
                      const Icon(Icons.calendar_today, color: trainerPrimary),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Informe o nome do dia'
                    : null,
              ),

              const SizedBox(height: 24),

              Text(
                'Foco do Treino',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descrição (ex: Peito e Tríceps)',
                  hintText:
                      'Descreva quais grupos musculares ou o foco deste dia',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon:
                      const Icon(Icons.fitness_center, color: trainerPrimary),
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Informe o foco do treino'
                    : null,
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: trainerPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Adicionar Dia',
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
