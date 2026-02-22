import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/workout_service.dart';
import '../../services/workout_template_service.dart';
import '../../config/app_theme.dart';
import '../../widgets/searchable_selection.dart';
import 'create_workout_template_screen.dart';
import 'workout_details_screen.dart';

class CreateWorkoutScreen extends StatefulWidget {
  const CreateWorkoutScreen({super.key});

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _selectedStudent;
  Map<String, dynamic>? _selectedTemplate;

  String? _selectedGoal;
  String? _selectedLevel;
  DateTime? _startDate;
  DateTime? _endDate;

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
    'Atleta',
  ];

  bool _isLoading = false;
  bool _isLoadingStudents = true;
  bool _isLoadingTemplates = true;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _templates = [];

  static const trainerPrimary = AppTheme.primaryRed;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingStudents = true;
      _isLoadingTemplates = true;
    });

    try {
      final students = await WorkoutService.getMyStudents();
      final templates = await WorkoutTemplateService.getTemplates();

      if (mounted) {
        setState(() {
          _students = students;
          _isLoadingStudents = false;
          _templates = templates;
          _isLoadingTemplates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStudents = false;
          _isLoadingTemplates = false;
        });
      }
    }
  }

  void _confirmDeleteTemplate(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Excluir Modelo',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: Text(
          'Deseja realmente excluir o modelo "${template['name']}"?\nToda ficha gerada com ele permanecerá intacta.',
          style: GoogleFonts.lato(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            onPressed: () async {
              Navigator.pop(dialogContext); // fecha dialog
              setState(() => _isLoading = true);
              try {
                final res =
                    await WorkoutTemplateService.deleteTemplate(template['id']);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: Text(res['message']),
                    backgroundColor:
                        res['success'] ? Colors.green : AppTheme.accentRed,
                  ));
                  _selectedTemplate = null;
                  await _loadData();
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmEditTemplate(Map<String, dynamic> template) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateWorkoutTemplateScreen(templateToEdit: template),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um aluno')),
      );
      return;
    }
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um modelo de treino')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Obter modelo com seus dias
      final templateData = await WorkoutTemplateService.getTemplateById(
          _selectedTemplate!['id']);

      if (templateData == null) {
        throw Exception("Não foi possível carregar o modelo de treino.");
      }

      // 2. Criar Ficha no Banco
      final result = await WorkoutService.createWorkout(
        studentId: _selectedStudent!['id'],
        name:
            '${_selectedStudent!['nome'] ?? _selectedStudent!['name']} - ${templateData['name']}',
        description: templateData['description'],
        goal: _selectedGoal ?? templateData['goal'],
        difficultyLevel: _selectedLevel ?? templateData['difficulty_level'],
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!result['success']) {
        throw Exception(result['message']);
      }

      final workoutId = result['workout']['id'];

      // 3. Clonar os Dias do Modelo se existirem
      final List<dynamic> days = templateData['workout_template_days'] ?? [];
      for (var dayConfig in days) {
        await WorkoutService.addWorkoutDay(
          workoutId: workoutId,
          dayName: dayConfig['day_name'],
          dayNumber: dayConfig['day_number'],
          description: dayConfig['description'],
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ficha de treino gerada e atribuída!'),
            backgroundColor: trainerPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutDetailsScreen(
              workoutId: workoutId,
              workoutName: _selectedStudent!['nome'] ??
                  _selectedStudent!['name'] ??
                  'Treino',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar ficha: $e'),
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
          'Gerar Nova Ficha',
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
                          const Icon(Icons.info_outline_rounded,
                              color: trainerPrimary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Selecione um aluno e um modelo de treino já cadastrado para gerar a ficha automaticamente.',
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

                    // Seleção de Aluno
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

                    // Seleção de Modelo de Treino
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(_selectedTemplate?['id']),
                            readOnly: true,
                            onTap: _openTemplateSelector,
                            initialValue: _selectedTemplate != null
                                ? _selectedTemplate!['name']
                                : '',
                            decoration: InputDecoration(
                              labelText:
                                  'Selecione um modelo de treino já criado',
                              hintText: 'Ex: Hipertrofia A/B',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              suffixIcon: const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: trainerPrimary),
                            ),
                            validator: (v) => _selectedTemplate == null
                                ? 'Obrigatório selecionar um modelo'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 58,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: trainerPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CreateWorkoutTemplateScreen(),
                                ),
                              );
                              if (result == true) {
                                _loadData();
                              }
                            },
                            child: Text(
                              'Criar Treino',
                              style: GoogleFonts.lato(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedGoal,
                            decoration: InputDecoration(
                              labelText: 'Objetivo',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: _goals
                                .map((g) =>
                                    DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedGoal = v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedLevel,
                            decoration: InputDecoration(
                              labelText: 'Nível',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: _levels
                                .map((l) =>
                                    DropdownMenuItem(value: l, child: Text(l)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedLevel = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                setState(() => _startDate = date);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Data Início',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              suffixIcon: const Icon(Icons.calendar_today,
                                  color: trainerPrimary),
                            ),
                            controller: TextEditingController(
                              text: _startDate != null
                                  ? '${_startDate!.day.toString().padLeft(2, '0')}/${_startDate!.month.toString().padLeft(2, '0')}/${_startDate!.year}'
                                  : '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate ??
                                    _startDate?.add(const Duration(days: 30)) ??
                                    DateTime.now()
                                        .add(const Duration(days: 30)),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                setState(() => _endDate = date);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Data Fim (Opcional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              suffixIcon: const Icon(Icons.calendar_today,
                                  color: trainerPrimary),
                            ),
                            controller: TextEditingController(
                              text: _endDate != null
                                  ? '${_endDate!.day.toString().padLeft(2, '0')}/${_endDate!.month.toString().padLeft(2, '0')}/${_endDate!.year}'
                                  : '',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: AppTheme.borderGrey),
                              ),
                              child: Text(
                                'Cancelar',
                                style: GoogleFonts.lato(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryText,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveWorkout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: trainerPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: Text(
                                'Salvar',
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
                  ],
                ),
              ),
            ),
    );
  }

  void _openTemplateSelector() {
    if (_isLoadingTemplates) return;

    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredTemplates = _templates.where((t) {
              final name = t['name']?.toLowerCase() ?? '';
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Selecione um modelo de treino já criado',
                      style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryText),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Pesquisar treino...',
                        prefixIcon:
                            const Icon(Icons.search, color: trainerPrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (val) {
                        setSheetState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  Expanded(
                    child: filteredTemplates.isEmpty
                        ? Center(
                            child: Text(
                            searchQuery.isNotEmpty
                                ? 'Nenhum treino encontrado com "$searchQuery"'
                                : 'Nenhum modelo cadastrado.\nClique em "Criar Treino" para começar.',
                            textAlign: TextAlign.center,
                            style:
                                GoogleFonts.lato(color: AppTheme.secondaryText),
                          ))
                        : ListView.separated(
                            itemCount: filteredTemplates.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final template = filteredTemplates[index];
                              final isSelected =
                                  _selectedTemplate?['id'] == template['id'];
                              return ListTile(
                                tileColor: isSelected
                                    ? trainerPrimary.withOpacity(0.05)
                                    : Colors.transparent,
                                title: Text(
                                  template['name'] ?? 'Sem nome',
                                  style: GoogleFonts.lato(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? trainerPrimary
                                        : AppTheme.primaryText,
                                  ),
                                ),
                                subtitle: template['goal'] != null &&
                                        template['goal'].isNotEmpty
                                    ? Text(
                                        template['goal'],
                                        style: GoogleFonts.lato(
                                            fontSize: 12,
                                            color: AppTheme.secondaryText),
                                      )
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: trainerPrimary),
                                      onPressed: () {
                                        Navigator.pop(context); // Close sheet
                                        _confirmEditTemplate(template);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: AppTheme.accentRed),
                                      onPressed: () {
                                        Navigator.pop(context); // Close sheet
                                        _confirmDeleteTemplate(template);
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() => _selectedTemplate = template);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
