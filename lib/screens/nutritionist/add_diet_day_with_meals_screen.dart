import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/diet_service.dart';
import '../../config/app_theme.dart';

class AddDietDayWithMealsScreen extends StatefulWidget {
  final String dietId;

  const AddDietDayWithMealsScreen({
    super.key,
    required this.dietId,
  });

  @override
  State<AddDietDayWithMealsScreen> createState() =>
      _AddDietDayWithMealsScreenState();
}

class _AddDietDayWithMealsScreenState extends State<AddDietDayWithMealsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Dias da semana selecionados
  final Map<String, bool> _selectedDays = {
    'Segunda-feira': true,
    'Terça-feira': true,
    'Quarta-feira': true,
    'Quinta-feira': true,
    'Sexta-feira': true,
    'Sábado': true,
    'Domingo': true,
  };

  final List<Map<String, TextEditingController>> _meals = [];
  bool _isLoading = false;

  static const nutritionistPrimary = Color(0xFF2A9D8F);

  @override
  void initState() {
    super.initState();
    _addMeal(); // Adiciona uma refeição inicial
  }

  @override
  void dispose() {
    for (var meal in _meals) {
      meal['name']!.dispose();
      meal['time']!.dispose();
      meal['foods']!.dispose();
      meal['calories']!.dispose();
      meal['protein']?.dispose();
      meal['carbs']?.dispose();
      meal['fats']?.dispose();
    }
    super.dispose();
  }

  void _addMeal() {
    setState(() {
      _meals.add({
        'name': TextEditingController(),
        'time': TextEditingController(),
        'foods': TextEditingController(),
        'calories': TextEditingController(),
        'protein': TextEditingController(),
        'carbs': TextEditingController(),
        'fats': TextEditingController(),
      });
    });
  }

  void _removeMeal(int index) {
    if (_meals.length > 1) {
      setState(() {
        _meals[index]['name']!.dispose();
        _meals[index]['time']!.dispose();
        _meals[index]['foods']!.dispose();
        _meals[index]['calories']!.dispose();
        _meals[index]['protein']?.dispose();
        _meals[index]['carbs']?.dispose();
        _meals[index]['fats']?.dispose();
        _meals.removeAt(index);
      });
    }
  }

  bool get _allDaysSelected =>
      _selectedDays.values.every((selected) => selected);

  void _toggleAllDays() {
    setState(() {
      final newValue = !_allDaysSelected;
      _selectedDays.updateAll((key, value) => newValue);
    });
  }

  List<String> get _getSelectedDays {
    return _selectedDays.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  Future<void> _saveMealsForDays() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedDays = _getSelectedDays;
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um dia da semana'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Mapear dias da semana para números (1-7)
      final dayNumbers = {
        'Segunda-feira': 1,
        'Terça-feira': 2,
        'Quarta-feira': 3,
        'Quinta-feira': 4,
        'Sexta-feira': 5,
        'Sábado': 6,
        'Domingo': 7,
      };

      // Para cada dia selecionado
      for (var dayName in selectedDays) {
        final dayNumber = dayNumbers[dayName]!;
        String dayId;

        // 1. Tentar obter o dia existente ou criar um novo
        try {
          // Tenta criar (a constraint unique vai falhar se já existir, mas addDietDay deveria tratar isso)
          // Mas como o erro está vindo do banco, vamos usar getOrCreateDietDay
          // Como não temos esse método, vamos tentar adicionar e capturar o erro, ou buscar antes

          // Melhor abordagem: Buscar se o dia já existe
          final existingDay =
              await DietService.getDietDay(widget.dietId, dayNumber);

          if (existingDay != null) {
            dayId = existingDay['id'];
          } else {
            // Se não existe, cria
            final dayResult = await DietService.addDietDay(
              dietId: widget.dietId,
              dayNumber: dayNumber,
              dayName: dayName,
            );

            if (!dayResult['success']) {
              // Se falhou por duplicidade (corrida), tenta buscar de novo
              if (dayResult['message'].contains('duplicate') ||
                  dayResult['message'].contains('23505')) {
                // Código de erro postgres unique violation
                final retryDay =
                    await DietService.getDietDay(widget.dietId, dayNumber);
                if (retryDay != null) {
                  dayId = retryDay['id'];
                } else {
                  throw Exception('Erro ao criar dia: ${dayResult['message']}');
                }
              } else {
                throw Exception(dayResult['message']);
              }
            } else {
              dayId = dayResult['day']['id'];
            }
          }
        } catch (e) {
          // Fallback se algo der errado na lógica acima, tenta criar e se der erro assume que existe
          print('Erro ao gerenciar dia $dayName: $e');
          // Tentar buscar novamente em caso de erro
          final checkDay =
              await DietService.getDietDay(widget.dietId, dayNumber);
          if (checkDay != null) {
            dayId = checkDay['id'];
          } else {
            rethrow;
          }
        }

        // 2. Adicionar todas as refeições para este dia
        for (var meal in _meals) {
          if (meal['name']!.text.isNotEmpty) {
            final calories = int.tryParse(meal['calories']!.text) ?? 0;
            final protein = int.tryParse(meal['protein']!.text);
            final carbs = int.tryParse(meal['carbs']!.text);
            final fats = int.tryParse(meal['fats']!.text);

            await DietService.addMeal(
              dietDayId: dayId,
              mealName: meal['name']!.text,
              mealTime: meal['time']!.text,
              foods: meal['foods']!.text,
              calories: calories,
              protein: protein,
              carbs: carbs,
              fats: fats,
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refeições adicionadas para ${selectedDays.length} dia(s)!',
            ),
            backgroundColor: nutritionistPrimary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Adicionar Refeições',
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
                    // Seleção de Dias da Semana
                    _buildCard(
                      icon: Icons.calendar_today_rounded,
                      title: 'Dias da Semana',
                      child: Column(
                        children: [
                          // Botão "Todos os dias"
                          InkWell(
                            onTap: _toggleAllDays,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _allDaysSelected
                                    ? nutritionistPrimary.withOpacity(0.1)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _allDaysSelected
                                      ? nutritionistPrimary
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _allDaysSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: _allDaysSelected
                                        ? nutritionistPrimary
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Todos os dias',
                                    style: GoogleFonts.lato(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _allDaysSelected
                                          ? nutritionistPrimary
                                          : AppTheme.primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Lista de dias individuais
                          ..._selectedDays.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDays[entry.key] = !entry.value;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: entry.value
                                        ? nutritionistPrimary.withOpacity(0.05)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: entry.value
                                          ? nutritionistPrimary
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        entry.value
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        color: entry.value
                                            ? nutritionistPrimary
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        entry.key,
                                        style: GoogleFonts.lato(
                                          fontSize: 15,
                                          fontWeight: entry.value
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: entry.value
                                              ? AppTheme.primaryText
                                              : AppTheme.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Refeições
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Refeições',
                          style: GoogleFonts.lato(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addMeal,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Adicionar'),
                          style: TextButton.styleFrom(
                            foregroundColor: nutritionistPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: nutritionistPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: nutritionistPrimary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: nutritionistPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'As refeições serão adicionadas para todos os dias selecionados',
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                color: nutritionistPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Lista de refeições
                    ..._meals.asMap().entries.map((entry) {
                      final index = entry.key;
                      final meal = entry.value;
                      return _buildMealCard(index, meal);
                    }),

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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildMealCard(int index, Map<String, TextEditingController> meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nutritionistPrimary.withOpacity(0.2)),
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
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: nutritionistPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Refeição ${index + 1}',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              const Spacer(),
              if (_meals.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.accentRed),
                  onPressed: () => _removeMeal(index),
                  tooltip: 'Remover refeição',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Nome e Horário
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: meal['name'],
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Café da Manhã',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Obrigatório';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: meal['time'],
                  decoration: InputDecoration(
                    labelText: 'Horário',
                    hintText: '07:00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Obrigatório';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Alimentos
          TextFormField(
            controller: meal['foods'],
            decoration: InputDecoration(
              labelText: 'Alimentos',
              hintText: '2 ovos, 1 pão integral, 1 banana...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Informe os alimentos';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Calorias e Macros
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: meal['calories'],
                  decoration: InputDecoration(
                    labelText: 'Calorias',
                    hintText: '500',
                    suffixText: 'kcal',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Obrigatório';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Digite um número';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: meal['protein'],
                  decoration: InputDecoration(
                    labelText: 'Proteína',
                    hintText: '30',
                    suffixText: 'g',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        int.tryParse(value) == null) {
                      return 'Inválido';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: meal['carbs'],
                  decoration: InputDecoration(
                    labelText: 'Carboidratos',
                    hintText: '50',
                    suffixText: 'g',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: meal['fats'],
                  decoration: InputDecoration(
                    labelText: 'Gorduras',
                    hintText: '15',
                    suffixText: 'g',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final selectedCount = _getSelectedDays.length;

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
        onPressed: _isLoading ? null : _saveMealsForDays,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_rounded, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Salvar Refeições',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (selectedCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Para $selectedCount dia(s) selecionado(s)',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
