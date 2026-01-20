import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/diet_service.dart';
import '../../services/user_service.dart';
import '../../config/app_theme.dart';
import '../../widgets/searchable_selection.dart';

class EditDietScreen extends StatefulWidget {
  final Map<String, dynamic> diet;

  const EditDietScreen({
    super.key,
    required this.diet,
  });

  @override
  State<EditDietScreen> createState() => _EditDietScreenState();
}

class _EditDietScreenState extends State<EditDietScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _caloriesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedGoal;
  Map<String, dynamic>? _selectedStudent;
  List<Map<String, dynamic>> _students = [];
  bool _isLoadingStudents = false;
  bool _isSaving = false;

  static const nutritionistPrimary = Color(0xFF2A9D8F);

  final List<String> _goals = [
    'Perda de Peso',
    'Ganho de Massa',
    'Manutenção',
    'Definição',
    'Saúde Geral',
  ];

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _initializeFields();
  }

  void _initializeFields() {
    _nameController.text = widget.diet['name_diet'] ?? '';
    _descriptionController.text = widget.diet['description'] ?? '';
    _caloriesController.text = widget.diet['total_calories']?.toString() ?? '';
    _selectedGoal = widget.diet['objective_diet'];

    if (widget.diet['start_date'] != null) {
      _startDate = DateTime.parse(widget.diet['start_date']);
    }
    if (widget.diet['end_date'] != null) {
      _endDate = DateTime.parse(widget.diet['end_date']);
    }

    // O aluno será carregado quando a lista de alunos estiver pronta
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final students = await UserService.getStudentsForStaff();
      setState(() {
        _students = students;
        _isLoadingStudents = false;

        // Encontrar o aluno selecionado
        if (widget.diet['student_id'] != null) {
          _selectedStudent = _students.firstWhere(
            (s) => s['id'] == widget.diet['student_id'],
            orElse: () => {},
          );
          if (_selectedStudent!.isEmpty) {
            _selectedStudent = null;
          }
        }
      });
    } catch (e) {
      setState(() => _isLoadingStudents = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar alunos: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: nutritionistPrimary,
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
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: nutritionistPrimary,
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

  Future<void> _saveDiet() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione a data de início'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final result = await DietService.updateDiet(
        dietId: widget.diet['id'],
        nameDiet: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        objectiveDiet: _selectedGoal,
        totalCalories: _caloriesController.text.isEmpty
            ? null
            : int.tryParse(_caloriesController.text),
        startDate: _startDate!.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
        studentId: _selectedStudent?['id'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor:
                result['success'] ? nutritionistPrimary : AppTheme.accentRed,
          ),
        );

        if (result['success']) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar dieta: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Editar Dieta',
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [nutritionistPrimary, Color(0xFF4CAF50)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nome da dieta
                    _buildCard(
                      icon: Icons.restaurant_menu_rounded,
                      title: 'Nome da Dieta',
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Dieta para Ganho de Massa',
                          border: InputBorder.none,
                        ),
                        style: GoogleFonts.lato(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe o nome da dieta';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Descrição
                    _buildCard(
                      icon: Icons.description_rounded,
                      title: 'Descrição (Opcional)',
                      child: TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          hintText: 'Descreva os objetivos e detalhes...',
                          border: InputBorder.none,
                        ),
                        style: GoogleFonts.lato(fontSize: 16),
                        maxLines: 3,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Aluno
                    _buildCard(
                      icon: Icons.person_rounded,
                      title: 'Aluno',
                      child: SearchableSelection<Map<String, dynamic>>(
                        label: 'Selecione o Aluno',
                        value: _selectedStudent,
                        items: _students,
                        labelBuilder: (student) =>
                            student['name'] ?? 'Sem nome',
                        hintText: 'Buscar aluno...',
                        onChanged: (value) {
                          setState(() => _selectedStudent = value);
                        },
                        isLoading: _isLoadingStudents,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Calorias Totais
                    _buildCard(
                      icon: Icons.local_fire_department_rounded,
                      title: 'Calorias Totais (Opcional)',
                      child: TextFormField(
                        controller: _caloriesController,
                        decoration: const InputDecoration(
                          hintText: 'Ex: 2000',
                          border: InputBorder.none,
                          suffixText: 'kcal',
                        ),
                        style: GoogleFonts.lato(fontSize: 16),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final calories = int.tryParse(value);
                            if (calories == null || calories < 0) {
                              return 'Informe um valor válido';
                            }
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Objetivo
                    _buildCard(
                      icon: Icons.flag_rounded,
                      title: 'Objetivo',
                      child: DropdownButtonFormField<String>(
                        value: _selectedGoal,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        hint: Text('Selecione o objetivo',
                            style: GoogleFonts.lato()),
                        items: _goals.map((goal) {
                          return DropdownMenuItem(
                            value: goal,
                            child: Text(goal, style: GoogleFonts.lato()),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedGoal = value),
                        validator: (value) {
                          if (value == null) {
                            return 'Selecione um objetivo';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Datas
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateCard(
                            icon: Icons.calendar_today_rounded,
                            title: 'Data de Início',
                            date: _startDate,
                            onTap: _selectStartDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateCard(
                            icon: Icons.event_rounded,
                            title: 'Data de Término',
                            date: _endDate,
                            onTap: _selectEndDate,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Botão salvar
                    _buildSaveButton(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: nutritionistPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: nutritionistPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDateCard({
    required IconData icon,
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date == null
                ? Colors.grey.shade300
                : nutritionistPrimary.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: nutritionistPrimary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              date != null
                  ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                  : 'Selecionar',
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                color:
                    date != null ? nutritionistPrimary : AppTheme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [nutritionistPrimary, Color(0xFF4CAF50)],
        ),
        boxShadow: [
          BoxShadow(
            color: nutritionistPrimary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveDiet,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Salvar Alterações',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
