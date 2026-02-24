import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/diet_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../config/app_theme.dart';
import 'diet_details_screen.dart';
import '../../widgets/searchable_selection.dart';

class CreateDietScreen extends StatefulWidget {
  const CreateDietScreen({super.key});

  @override
  State<CreateDietScreen> createState() => _CreateDietScreenState();
}

class _CreateDietScreenState extends State<CreateDietScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _caloriesController = TextEditingController();

  Map<String, dynamic>? _selectedStudent;
  String? _selectedGoal;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _isLoadingStudents = false;
  List<Map<String, dynamic>> _students = [];

  static const nutritionistPrimary = Color(0xFF2A9D8F);

  final List<String> _goals = [
    'Perda de Peso',
    'Ganho de Massa Muscular',
    'Manutenção',
    'Definição Muscular',
    'Saúde e Bem-estar',
    'Performance Esportiva',
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
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final students = await UserService.getStudentsForStaff();
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

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      initialDate: _endDate ??
          _startDate?.add(const Duration(days: 30)) ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um aluno'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    if (_selectedGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um objetivo'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = await AuthService.getCurrentUserData();

      final result = await DietService.createDiet(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        studentId: _selectedStudent!['id'],
        nutritionistId: currentUser!['id'],
        goal: _selectedGoal!,
        totalCalories: int.parse(_caloriesController.text),
        startDate: _startDate!.toIso8601String().split('T')[0],
        endDate: _endDate?.toIso8601String().split('T')[0],
      );

      if (mounted) {
        if (result['success']) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    DietDetailsScreen(dietId: result['diet']['id']),
              ),
            );
          }
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
            content: Text('Erro ao criar dieta: $e'),
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

  // Helper Widgets
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildModernCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.lato(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: nutritionistPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: nutritionistPrimary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
    );
  }

  Widget _buildModernDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGoal,
      decoration: InputDecoration(
        labelText: 'Objetivo',
        prefixIcon: Icon(Icons.flag_rounded, color: nutritionistPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: nutritionistPrimary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: _goals.map((goal) {
        return DropdownMenuItem(
          value: goal,
          child: Text(goal, style: GoogleFonts.lato(fontSize: 15)),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedGoal = value),
      validator: (value) {
        if (value == null) return 'Por favor, selecione um objetivo';
        return null;
      },
    );
  }

  Widget _buildModernDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool optional = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null ? nutritionistPrimary : Colors.grey[300]!,
            width: date != null ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: date != null ? nutritionistPrimary : Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Text(
                  date != null
                      ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                      : (optional ? 'Opcional' : 'Selecionar'),
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight:
                        date != null ? FontWeight.w600 : FontWeight.normal,
                    color:
                        date != null ? AppTheme.primaryText : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [nutritionistPrimary, Color(0xFF21867A)],
        ),
        boxShadow: [
          BoxShadow(
            color: nutritionistPrimary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? () {} : _saveDiet,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    'CRIAR DIETA',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar moderno com gradiente
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: nutritionistPrimary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Nova Dieta',
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [nutritionistPrimary, Color(0xFF21867A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon:
                  const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Conteúdo
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informações Básicas
                    _buildSectionHeader(
                        'Informações Básicas', Icons.edit_note_rounded),
                    const SizedBox(height: 16),
                    _buildModernCard(
                      child: Column(
                        children: [
                          _buildModernTextField(
                            controller: _nameController,
                            label: 'Nome da Dieta',
                            hint: 'Ex: Dieta para Emagrecimento',
                            icon: Icons.restaurant_menu_rounded,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira o nome da dieta';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildModernTextField(
                            controller: _descriptionController,
                            label: 'Descrição',
                            hint: 'Descreva os objetivos e características',
                            icon: Icons.description_outlined,
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira uma descrição';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Aluno
                    _buildSectionHeader('Aluno', Icons.person_rounded),
                    const SizedBox(height: 16),
                    _buildModernCard(
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

                    const SizedBox(height: 24),

                    // Objetivo e Calorias
                    _buildSectionHeader(
                        'Objetivo e Calorias', Icons.flag_rounded),
                    const SizedBox(height: 16),
                    _buildModernCard(
                      child: Column(
                        children: [
                          _buildModernDropdown(),
                          const SizedBox(height: 16),
                          _buildModernTextField(
                            controller: _caloriesController,
                            label: 'Calorias Totais (kcal/dia)',
                            hint: '2000',
                            icon: Icons.local_fire_department_rounded,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira as calorias totais';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Por favor, insira um número válido';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Período
                    _buildSectionHeader(
                        'Período', Icons.calendar_today_rounded),
                    const SizedBox(height: 16),
                    _buildModernCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildModernDateField(
                              label: 'Data de Início',
                              date: _startDate,
                              onTap: _selectStartDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModernDateField(
                              label: 'Data de Término',
                              date: _endDate,
                              onTap: _selectEndDate,
                              optional: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: nutritionistPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: nutritionistPrimary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: nutritionistPrimary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: nutritionistPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Você pode adicionar dias e refeições depois de criar a dieta',
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                color: nutritionistPrimary.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Botão Criar
                    _buildCreateButton(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
