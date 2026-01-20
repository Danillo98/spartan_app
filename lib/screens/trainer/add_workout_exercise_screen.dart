import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../services/workout_service.dart';

class AddWorkoutExerciseScreen extends StatefulWidget {
  final String workoutDayId;

  const AddWorkoutExerciseScreen({super.key, required this.workoutDayId});

  @override
  State<AddWorkoutExerciseScreen> createState() =>
      _AddWorkoutExerciseScreenState();
}

class _AddWorkoutExerciseScreenState extends State<AddWorkoutExerciseScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();

  final _weightController = TextEditingController();
  final _restController = TextEditingController();
  final _techniqueController = TextEditingController();
  final _videoController = TextEditingController();
  final _notesController = TextEditingController();

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

  // Banco de dados de exercícios por grupo muscular
  final Map<String, List<String>> _exerciseDatabase = {
    'Peito': [
      'Supino Reto Barra',
      'Supino Reto Halteres',
      'Supino Inclinado Barra',
      'Supino Inclinado Halteres',
      'Crucifixo Reto',
      'Crucifixo Inclinado',
      'Crossover Polia Alta',
      'Crossover Polia Baixa',
      'Voador (Peck Deck)',
      'Flexão de Braço'
    ],
    'Costas': [
      'Puxada Alta Aberta',
      'Puxada Alta Triângulo',
      'Remada Baixa Polia',
      'Remada Curvada Barra',
      'Remada Unilateral Halter (Serrote)',
      'Pulldown Corda',
      'Levantamento Terra',
      'Barra Fixa',
      'Voador Inverso'
    ],
    'Ombros': [
      'Desenvolvimento com Halteres',
      'Desenvolvimento com Barra (Militar)',
      'Elevação Lateral',
      'Elevação Frontal',
      'Crucifixo Inverso',
      'Remada Alta',
      'Encolhimento de Ombros'
    ],
    'Bíceps': [
      'Rosca Direta Barra',
      'Rosca Direta Halteres',
      'Rosca Martelo',
      'Rosca Scott',
      'Rosca Concentrada',
      'Rosca Alternada'
    ],
    'Tríceps': [
      'Tríceps Pulley Corda',
      'Tríceps Pulley Barra',
      'Tríceps Testa',
      'Tríceps Francês',
      'Tríceps Banco',
      'Mergulho Paralelas'
    ],
    'Quadríceps': [
      'Agachamento Livre',
      'Agachamento Smith',
      'Leg Press 45',
      'Cadeira Extensora',
      'Afundo com Halteres',
      'Bulgarian Split Squat'
    ],
    'Posterior': [
      'Mesa Flexora',
      'Cadeira Flexora',
      'Stiff com Barra',
      'Stiff com Halteres'
    ],
    'Glúteos': [
      'Elevação Pélvica',
      'Glúteo Caneleira 4 Apoios',
      'Cadeira Abdutora',
      'Agachamento Sumô'
    ],
    'Panturrilhas': [
      'Panturrilha em Pé (Máquina)',
      'Panturrilha Sentado',
      'Panturrilha no Leg Press'
    ],
    'Abdômen': [
      'Abdominal Supra',
      'Abdominal Infra',
      'Prancha Isométrica',
      'Abdominal Remador',
      'Russian Twist'
    ],
    'Cardio': [
      'Esteira - Corrida',
      'Esteira - Caminhada',
      'Bicicleta Ergométrica',
      'Elíptico',
      'Escada'
    ],
    'Funcional': ['Burpee', 'Polichinelo', 'Corda Naval', 'Box Jump']
  };

  @override
  void dispose() {
    _nameController.dispose();
    _setsController.dispose();
    _repsController.dispose();

    _weightController.dispose();
    _restController.dispose();
    _techniqueController.dispose();
    _videoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await WorkoutService.addExercise(
        workoutDayId: widget.workoutDayId,
        name: _nameController.text,
        muscleGroup: _selectedMuscleGroup,
        sets: int.parse(_setsController.text),
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
            content: Text('Erro ao adicionar exercício: $e'),
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
          'Adicionar Exercício',
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
              // Nome e Grupo Muscular
              _buildSectionTitle('Identificação'),
              const SizedBox(height: 16),

              // 1. Grupo Muscular (Primeiro)
              DropdownButtonFormField<String>(
                value: _selectedMuscleGroup,
                decoration:
                    _inputDecoration('Grupo Muscular', Icons.accessibility_new),
                items: _muscleGroups.map((group) {
                  // Mapeamento de imagens
                  final Map<String, String> muscleImages = {
                    'Peito': 'assets/images/muscle_chest.png',
                    'Costas': 'assets/images/muscle_back.png',
                    'Ombros': 'assets/images/muscle_shoulders.png',
                    'Bíceps': 'assets/images/muscle_biceps.png',
                    'Tríceps': 'assets/images/muscle_triceps.png',
                    'Quadríceps': 'assets/images/muscle_quadriceps.png',
                    'Posterior': 'assets/images/muscle_hamstrings.png',
                    'Glúteos': 'assets/images/muscle_glutes.png',
                    'Panturrilhas': 'assets/images/muscle_calves.png',
                    'Abdômen': 'assets/images/muscle_abs.png',
                    'Cardio': 'assets/images/muscle_cardio.png',
                    'Funcional': 'assets/images/muscle_functional.png',
                  };

                  final imageAsset = muscleImages[group];

                  return DropdownMenuItem(
                    value: group,
                    child: Row(
                      children: [
                        if (imageAsset != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  imageAsset,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(Icons.accessibility_new,
                                color: Colors.grey),
                          ),
                        Text(
                          group,
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMuscleGroup = value;
                    // Opcional: Limpar nome ao trocar grupo?
                    // _nameController.clear();
                    // Melhor não limpar, pode frustrar se trocar sem querer.
                  });
                },
                validator: (value) =>
                    value == null ? 'Selecione um grupo muscular' : null,
              ),
              const SizedBox(height: 16),

              // 2. Nome do Exercício (Segundo, com Autocomplete)
              LayoutBuilder(
                builder: (context, constraints) {
                  return Autocomplete<String>(
                    key: ValueKey(_selectedMuscleGroup ?? 'default'),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (_selectedMuscleGroup == null) {
                        return const Iterable<String>.empty();
                      }

                      final exercises =
                          _exerciseDatabase[_selectedMuscleGroup] ?? [];

                      if (textEditingValue.text.isEmpty) {
                        return exercises;
                      }

                      return exercises.where((option) {
                        return option.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                      });
                    },
                    onSelected: (String selection) {
                      _nameController.text = selection;
                    },
                    fieldViewBuilder: (
                      BuildContext context,
                      TextEditingController fieldTextEditingController,
                      FocusNode fieldFocusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      // Sincronizar controlador interno do Autocomplete com o nosso _nameController
                      // OU usar o nosso _nameController DIRETO se possível, mas Autocomplete cria o dele.
                      // Truque: Quando o Autocomplete cria o controller, nós o usamos como referência
                      // Mas precisamos persistir o valor no _nameController para o salvar.
                      // Melhor abordagem: Usar o onChanged do fieldTextEditingController para atualizar o _nameController

                      // Porém, Autocomplete não expõe fácil o controller externo.
                      // Vamos fazer assim: No _saveExercise usaremos o _nameController.
                      // Precisamos garantir que o que se digita aqui vai pro _nameController.

                      if (fieldTextEditingController.text !=
                          _nameController.text) {
                        fieldTextEditingController.text = _nameController.text;
                      }

                      fieldTextEditingController.addListener(() {
                        _nameController.text = fieldTextEditingController.text;
                      });

                      return TextFormField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        decoration: _inputDecoration(
                            'Nome do Exercício', Icons.fitness_center),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Informe o nome'
                            : null,
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: Container(
                            width:
                                constraints.maxWidth, // Largura igual ao campo
                            color: Colors.white,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option),
                                  onTap: () {
                                    onSelected(option);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
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
                  onPressed: _isLoading ? null : _saveExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: trainerPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Salvar Exercício',
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
