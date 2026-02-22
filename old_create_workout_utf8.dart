import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/workout_service.dart';
import '../../config/app_theme.dart';
import '../../widgets/searchable_selection.dart';

class CreateWorkoutScreen extends StatefulWidget {
  const CreateWorkoutScreen({super.key});

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  Map<String, dynamic>? _selectedStudent;
  String? _selectedGoal;
  String? _selectedLevel;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _isLoadingStudents = false;
  List<Map<String, dynamic>> _students = [];

  // Nova estrutura: Map com detalhes de cada dia selecionado
  final List<String> _availableDays = [
    'Segunda-feira',
    'Ter├ºa-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'S├íbado',
    'Domingo'
  ];

  // Armazena os dias configurados: {dayName: {description, duration, sets}}
  final Map<String, Map<String, dynamic>> _configuredDays = {};

  static const trainerPrimary = AppTheme.primaryRed;

  final List<String> _goals = [
    'Hipertrofia',
    'For├ºa M├íxima',
    'Emagrecimento',
    'Resist├¬ncia Muscular',
    'Condicionamento',
    'Flexibilidade',
    'Reabilita├º├úo',
  ];

  final List<String> _levels = [
    'Iniciante',
    'Intermedi├írio',
    'Avan├ºado',
    'Atleta',
  ];

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _startDate = DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final students = await WorkoutService.getMyStudents();
      setState(() {
        _students = students;
        _isLoadingStudents = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar alunos: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um aluno'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    if (_configuredDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure pelo menos um dia de treino'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Criar o Treino (Header)
      final result = await WorkoutService.createWorkout(
        studentId: _selectedStudent!['id'],
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        goal: _selectedGoal,
        difficultyLevel: _selectedLevel,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!result['success']) {
        throw Exception(result['message']);
      }

      final workoutId = result['workout']['id'];

      // 2. Criar os Dias Configurados
      int dayNumber = 1;
      for (var entry in _configuredDays.entries) {
        final dayName = entry.key;
        final dayConfig = entry.value;

        await WorkoutService.addWorkoutDay(
          workoutId: workoutId,
          dayName: dayName,
          dayNumber: dayNumber++,
          description: dayConfig['description'],
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ficha de treino criada com sucesso!'),
            backgroundColor: trainerPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar treino: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text(
          'Nova Ficha de Treino',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: trainerPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: trainerPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Texto introdut├│rio
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: trainerPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: trainerPrimary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: trainerPrimary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Crie uma nova ficha de treino personalizada para seu aluno.',
                              style: GoogleFonts.lato(
                                color: trainerPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sele├º├úo de Aluno com Pesquisa
                    SearchableSelection<Map<String, dynamic>>(
                      label: 'Selecione o Aluno',
                      value: _selectedStudent,
                      items: _students,
                      labelBuilder: (student) => student['name'] ?? 'Sem nome',
                      hintText: 'Buscar aluno...',
                      onChanged: (value) {
                        setState(() => _selectedStudent = value);
                      },
                      isLoading: _isLoadingStudents,
                    ),

                    const SizedBox(height: 16),

                    // Nome da Ficha
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Nome da Ficha',
                        hintText: 'Ex: Hipertrofia Fase 1',
                        prefixIcon: const Icon(Icons.fitness_center,
                            color: trainerPrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor informe o nome da ficha';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Objetivo e N├¡vel
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Objetivo',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: _selectedGoal,
                            items: _goals.map((goal) {
                              return DropdownMenuItem(
                                value: goal,
                                child: Text(
                                  goal,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedGoal = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'N├¡vel',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: _selectedLevel,
                            items: _levels.map((level) {
                              return DropdownMenuItem(
                                value: level,
                                child: Text(level),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedLevel = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Descri├º├úo
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Descri├º├úo / Observa├º├Áes',
                        hintText: 'Detalhes sobre a periodiza├º├úo...',
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(Icons.description,
                            color: trainerPrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sele├º├úo de Dias (Novo - Com Configura├º├úo)
                    Text(
                      'Dias de Treino',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Dias j├í configurados
                    if (_configuredDays.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: trainerPrimary.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: _configuredDays.entries.map((entry) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: trainerPrimary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: trainerPrimary.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: GoogleFonts.lato(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: trainerPrimary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        size: 18, color: AppTheme.accentRed),
                                    onPressed: () {
                                      setState(() =>
                                          _configuredDays.remove(entry.key));
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Bot├úo para adicionar dia
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableDays.map((day) {
                          final isConfigured = _configuredDays.containsKey(day);
                          return FilterChip(
                            label: Text(day),
                            selected: isConfigured,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  // Adiciona o dia diretamente sem popup
                                  _configuredDays[day] = {
                                    'description': 'Treino de $day',
                                  };
                                } else {
                                  _configuredDays.remove(day);
                                }
                              });
                            },
                            checkmarkColor: Colors.white,
                            backgroundColor: Colors.grey[100],
                            selectedColor: trainerPrimary,
                            labelStyle: GoogleFonts.lato(
                              color:
                                  isConfigured ? Colors.white : Colors.black87,
                              fontWeight: isConfigured
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Per├¡odo de Validade (Calend├írio)
                    Text(
                      'Per├¡odo de Validade',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectStartDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'In├¡cio',
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      color: AppTheme.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          size: 16, color: trainerPrimary),
                                      const SizedBox(width: 8),
                                      Text(
                                        _startDate != null
                                            ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                            : 'Selecionar',
                                        style: GoogleFonts.lato(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _selectEndDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fim (Opcional)',
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      color: AppTheme.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.event,
                                          size: 16, color: trainerPrimary),
                                      const SizedBox(width: 8),
                                      Text(
                                        _endDate != null
                                            ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                            : 'Selecionar',
                                        style: GoogleFonts.lato(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Bot├úo Salvar
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveWorkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: trainerPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: trainerPrimary.withOpacity(0.4),
                        ),
                        child: Text(
                          'Criar Ficha',
                          style: GoogleFonts.lato(
                            fontSize: 18,
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

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: trainerPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ??
          (_startDate?.add(const Duration(days: 30)) ?? DateTime.now()),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: trainerPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }
}
