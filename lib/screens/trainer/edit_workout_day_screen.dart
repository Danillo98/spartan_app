import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../services/workout_service.dart';

class EditWorkoutDayScreen extends StatefulWidget {
  final String dayId;
  final String currentName;
  final String? currentDescription;

  const EditWorkoutDayScreen({
    super.key,
    required this.dayId,
    required this.currentName,
    this.currentDescription,
  });

  @override
  State<EditWorkoutDayScreen> createState() => _EditWorkoutDayScreenState();
}

class _EditWorkoutDayScreenState extends State<EditWorkoutDayScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;

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
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _descriptionController =
        TextEditingController(text: widget.currentDescription);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await WorkoutService.updateWorkoutDay(
        dayId: widget.dayId,
        dayName: _nameController.text,
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
            content: Text('Erro ao atualizar dia: $e'),
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
          'Editar Dia de Treino',
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
                  labelText: 'Nome do Dia',
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
                  labelText: 'Descrição (Opcional)',
                  hintText:
                      'Descreva quais grupos musculares ou o foco deste dia',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon:
                      const Icon(Icons.fitness_center, color: trainerPrimary),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: trainerPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Salvar Alterações',
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
