import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/diet_service.dart';
import '../../config/app_theme.dart';

class EditMealScreen extends StatefulWidget {
  final Map<String, dynamic> meal;
  final String dayName;

  const EditMealScreen({
    super.key,
    required this.meal,
    required this.dayName,
  });

  @override
  State<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends State<EditMealScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _timeController;
  late TextEditingController _foodsController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatsController;

  bool _isLoading = false;

  static const nutritionistPrimary = Color(0xFF2A9D8F);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.meal['meal_name']);
    _timeController = TextEditingController(text: widget.meal['meal_time']);
    _foodsController = TextEditingController(text: widget.meal['foods']);
    _caloriesController =
        TextEditingController(text: widget.meal['calories']?.toString() ?? '');
    _proteinController =
        TextEditingController(text: widget.meal['protein']?.toString() ?? '');
    _carbsController =
        TextEditingController(text: widget.meal['carbs']?.toString() ?? '');
    _fatsController =
        TextEditingController(text: widget.meal['fats']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    _foodsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  Future<void> _saveMeal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await DietService.updateMeal(
        mealId: widget.meal['id'],
        mealName: _nameController.text,
        mealTime: _timeController.text,
        foods: _foodsController.text,
        calories: int.parse(_caloriesController.text),
        protein: _proteinController.text.isEmpty
            ? null
            : int.tryParse(_proteinController.text),
        carbs: _carbsController.text.isEmpty
            ? null
            : int.tryParse(_carbsController.text),
        fats: _fatsController.text.isEmpty
            ? null
            : int.tryParse(_fatsController.text),
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
            content: Text('Erro ao atualizar refeição: $e'),
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
          'Editar Refeição',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: nutritionistPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info do dia
            Container(
              padding: const EdgeInsets.all(16),
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
                    Icons.edit_calendar_rounded,
                    color: nutritionistPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Editando: ${widget.dayName}',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: nutritionistPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Card com formulário
            Container(
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
                  // Nome e Horário
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nome da Refeição',
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
                        child: InkWell(
                          onTap: () async {
                            TimeOfDay initialTime = TimeOfDay.now();
                            if (_timeController.text.isNotEmpty) {
                              try {
                                final parts = _timeController.text.split(':');
                                if (parts.length == 2) {
                                  initialTime = TimeOfDay(
                                    hour: int.parse(parts[0]),
                                    minute: int.parse(parts[1]),
                                  );
                                }
                              } catch (_) {}
                            }
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: initialTime,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                        primary: nutritionistPrimary),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              // Formatar HH:mm
                              final now = DateTime.now();
                              final dt = DateTime(now.year, now.month, now.day,
                                  picked.hour, picked.minute);
                              // Requer intl import no topo, mas se não tiver, formatted string manual:
                              final hour =
                                  picked.hour.toString().padLeft(2, '0');
                              final minute =
                                  picked.minute.toString().padLeft(2, '0');
                              _timeController.text = '$hour:$minute';
                            }
                          },
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _timeController,
                              decoration: InputDecoration(
                                labelText: 'Horário',
                                hintText: '07:00',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                suffixIcon: const Icon(Icons.access_time),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Obrigatório';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Alimentos
                  TextFormField(
                    controller: _foodsController,
                    decoration: InputDecoration(
                      labelText: 'Alimentos',
                      hintText: '2 ovos, 1 pão integral, 1 banana...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe os alimentos';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Calorias
                  TextFormField(
                    controller: _caloriesController,
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
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Macronutrientes (Opcional)',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryText,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Proteína e Carboidratos
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _proteinController,
                          decoration: InputDecoration(
                            labelText: 'Proteína',
                            hintText: '30',
                            suffixText: 'g',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _carbsController,
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
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Gorduras
                  TextFormField(
                    controller: _fatsController,
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
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botão salvar
            Container(
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
                onPressed: _isLoading ? null : _saveMeal,
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
            ),
          ],
        ),
      ),
    );
  }
}
