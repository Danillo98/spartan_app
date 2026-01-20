import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../services/workout_service.dart';

class EditWorkoutExerciseScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;

  const EditWorkoutExerciseScreen({super.key, required this.exercise});

  @override
  State<EditWorkoutExerciseScreen> createState() =>
      _EditWorkoutExerciseScreenState();
}

class _EditWorkoutExerciseScreenState extends State<EditWorkoutExerciseScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _setsController;
  late TextEditingController _repsController;

  late TextEditingController _weightController;
  late TextEditingController _restController;

  String? _selectedMuscleGroup;
  bool _isLoading = false;

  static const trainerPrimary = AppTheme.primaryRed;

  final List<String> _muscleGroups = [
    'Peito',
    'Costas',
    'Ombros',
    'Bíceps',
    'Tríceps',
    'Quadríceps',
    'Posterior',
    'Glúteos',
    'Panturrilhas',
    'Abdômen',
    'Cardio',
    'Funcional',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    _nameController = TextEditingController(text: e['exercise_name']);
    _setsController = TextEditingController(text: e['sets']?.toString() ?? '');
    _repsController = TextEditingController(text: e['reps'] ?? '');

    _weightController =
        TextEditingController(text: e['weight_kg']?.toString() ?? '');
    _restController =
        TextEditingController(text: e['rest_seconds']?.toString() ?? '');
    _selectedMuscleGroup = e['muscle_group'];

    // Check if muscle group is valid, else reset or add logic (simplified here)
    if (_selectedMuscleGroup != null &&
        !_muscleGroups.contains(_selectedMuscleGroup)) {
      _selectedMuscleGroup = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _setsController.dispose();
    _repsController.dispose();

    _weightController.dispose();
    _restController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await WorkoutService.updateExercise(
        exerciseId: widget.exercise['id'],
        name: _nameController.text,
        muscleGroup: _selectedMuscleGroup,
        sets: int.tryParse(_setsController.text),
        reps: _repsController.text,
        weight: int.tryParse(_weightController.text),
        restSeconds: int.tryParse(_restController.text),
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
            content: Text('Erro ao atualizar exercício: $e'),
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
          'Editar Exercício',
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
              _buildSectionTitle('Identificação'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration:
                    _inputDecoration('Nome do Exercício', Icons.fitness_center),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMuscleGroup,
                decoration:
                    _inputDecoration('Grupo Muscular', Icons.accessibility_new),
                items: _muscleGroups
                    .map((group) => DropdownMenuItem(
                          value: group,
                          child: Text(group),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedMuscleGroup = value),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Volume e Carga'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _setsController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Séries', Icons.repeat),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _repsController,
                      decoration: _inputDecoration('Repetições', Icons.numbers),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration:
                          _inputDecoration('Carga (kg)', Icons.monitor_weight),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _restController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Descanso', Icons.timelapse),
                    ),
                  ),
                ],
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.lato(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: trainerPrimary,
        letterSpacing: 1.0,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: trainerPrimary, width: 2),
      ),
      prefixIcon: Icon(icon, color: Colors.grey.shade600),
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}
