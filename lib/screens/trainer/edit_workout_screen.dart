import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
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

  final List<Uint8List> _attachedImages = [];

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
    String rawDescription = widget.workout['description'] ?? '';

    final RegExp regExp = RegExp(r'\[IMG_BASE64:([^\]]+)\]');
    final matches = regExp.allMatches(rawDescription);

    for (var match in matches) {
      final base64String = match.group(1);
      if (base64String != null) {
        try {
          _attachedImages.add(base64Decode(base64String.trim()));
        } catch (e) {
          // ignore
        }
      }
    }

    rawDescription = rawDescription.replaceAll(regExp, '').trim();
    _descriptionController = TextEditingController(text: rawDescription);

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
      String finalDescription = _descriptionController.text;

      // Anexar base64 das imagens comprimidas na descrição
      if (_attachedImages.isNotEmpty) {
        for (var bytes in _attachedImages) {
          final base64String = base64Encode(bytes);
          finalDescription += '\n[IMG_BASE64:$base64String]';
        }
      }

      final result = await WorkoutService.updateWorkout(
        workoutId: widget.workout['id'],
        name: _nameController.text,
        description: finalDescription.isEmpty ? null : finalDescription,
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
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text('Editar Ficha',
            style: GoogleFonts.lato(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: trainerPrimary,
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
                              'Edite os dados principais desta ficha de treino atual.',
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

                    // Nome da Ficha
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome da Ficha',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.fitness_center,
                            color: trainerPrimary),
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

                    // Descrição
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _descriptionController,
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Descrição / Informações Adicionais',
                              alignLabelWithHint: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                          if (_attachedImages.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _attachedImages
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final index = entry.key;
                                  final bytes = entry.value;
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          bytes,
                                          height: 100,
                                          width: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _attachedImages.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.all(4),
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.black.withOpacity(0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close,
                                                color: Colors.white, size: 16),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.image,
                                      color: Colors.blueGrey),
                                  onPressed: () async {
                                    try {
                                      final picker = ImagePicker();
                                      final image = await picker.pickImage(
                                          source: ImageSource.gallery);
                                      if (image != null) {
                                        Uint8List bytes =
                                            await image.readAsBytes();

                                        try {
                                          final compressed =
                                              await FlutterImageCompress
                                                  .compressWithList(
                                            bytes,
                                            minHeight: 1024,
                                            minWidth: 1024,
                                            quality: 75,
                                          );
                                          bytes =
                                              Uint8List.fromList(compressed);
                                        } catch (e) {
                                          // Handle error
                                        }
                                        setState(() {
                                          _attachedImages.add(bytes);
                                        });
                                      }
                                    } catch (e) {
                                      // Ignore
                                    }
                                  },
                                  tooltip: 'Anexar Imagem',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Datas
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            onTap: _selectStartDate,
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
                            onTap: _selectEndDate,
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
                              onPressed: _saveChanges,
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
}
