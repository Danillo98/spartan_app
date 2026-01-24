import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/workout_service.dart';
import '../../config/app_theme.dart';

class EditWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic> workout;

  const EditWorkoutScreen({super.key, required this.workout});

  @override
  State<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends State<EditWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  String? _selectedGoal;
  String? _selectedLevel;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _isLoading = false;

  static const trainerPrimary = AppTheme.primaryRed;

  final List<String> _goals = [
    'Hipertrofia',
    'Força Máxima',
    'Emagrecimento',
    'Resistência Muscular',
    'Condicionamento',
    'Flexibilidade',
    'Reabilitação',
  ];

  final List<String> _levels = [
    'Iniciante',
    'Intermediário',
    'Avançado',
    'Atleta'
  ];

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    _nameController = TextEditingController(text: widget.workout['name'] ?? '');
    _descriptionController =
        TextEditingController(text: widget.workout['description'] ?? '');
    _selectedGoal = widget.workout['goal'];
    _selectedLevel = widget.workout['difficulty_level'];
    _isActive = widget.workout['is_active'] ?? true;

    // Validate values against lists
    if (_selectedGoal != null && !_goals.contains(_selectedGoal))
      _selectedGoal = null;
    if (_selectedLevel != null && !_levels.contains(_selectedLevel))
      _selectedLevel = null;

    if (widget.workout['start_date'] != null) {
      _startDate = DateTime.parse(widget.workout['start_date']);
    }
    if (widget.workout['end_date'] != null) {
      _endDate = DateTime.parse(widget.workout['end_date']);
    }
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
      final result = await WorkoutService.updateWorkout(
        workoutId: widget.workout['id'],
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        goal: _selectedGoal,
        difficultyLevel: _selectedLevel,
        isActive: _isActive,
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
      );

      if (mounted) {
        if (result['success']) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(result['message'])));
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: trainerPrimary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: trainerPrimary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Editar Ficha',
            style: GoogleFonts.lato(
                fontWeight: FontWeight.bold, color: Colors.white)),
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
              // Nome da Ficha
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome da Ficha',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon:
                      const Icon(Icons.fitness_center, color: trainerPrimary),
                ),
                validator: (v) => v!.isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),

              // Objetivo e Nível
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGoal,
                      isExpanded: true,
                      items: _goals
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedGoal = v),
                      decoration: InputDecoration(
                          labelText: 'Objetivo',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedLevel,
                      isExpanded: true,
                      items: _levels
                          .map(
                              (l) => DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedLevel = v),
                      decoration: InputDecoration(
                          labelText: 'Nível',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Descrição
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon:
                      const Icon(Icons.description, color: trainerPrimary),
                ),
              ),
              const SizedBox(height: 16),

              // Datas
              Row(
                children: [
                  Expanded(
                      child: _buildDateButton(
                          'Início', _startDate, _selectStartDate)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildDateButton('Fim', _endDate, _selectEndDate)),
                ],
              ),
              const SizedBox(height: 32),

              // Botão Salvar
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
                      : Text('Salvar Alterações',
                          style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.lato(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today, size: 16, color: trainerPrimary),
              const SizedBox(width: 8),
              Text(
                  date != null
                      ? '${date.day}/${date.month}/${date.year}'
                      : 'Selecionar',
                  style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }
}
