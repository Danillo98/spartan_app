import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/workout_template_service.dart';
import '../../config/app_theme.dart';

class CreateWorkoutTemplateScreen extends StatefulWidget {
  final Map<String, dynamic>? templateToEdit;

  const CreateWorkoutTemplateScreen({super.key, this.templateToEdit});

  @override
  State<CreateWorkoutTemplateScreen> createState() =>
      _CreateWorkoutTemplateScreenState();
}

class _CreateWorkoutTemplateScreenState
    extends State<CreateWorkoutTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;

  final List<Uint8List> _attachedImages = [];

  static const trainerPrimary = AppTheme.primaryRed;

  @override
  void initState() {
    super.initState();
    if (widget.templateToEdit != null) {
      _nameController.text = widget.templateToEdit!['name'] ?? '';
      String rawDescription = widget.templateToEdit!['description'] ?? '';

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
      _descriptionController.text = rawDescription;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do modelo de treino')),
      );
      return;
    }

    if (_descriptionController.text.isEmpty && _attachedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insira uma descrição ou anexe fotos no Modelo'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

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

      final isEditing = widget.templateToEdit != null;

      final result = isEditing
          ? await WorkoutTemplateService.updateTemplate(
              templateId: widget.templateToEdit!['id'],
              name: _nameController.text.trim(),
              description: finalDescription.isEmpty ? null : finalDescription,
            )
          : await WorkoutTemplateService.createTemplate(
              name: _nameController.text.trim(),
              description: finalDescription.isEmpty ? null : finalDescription,
            );

      if (!result['success']) {
        throw Exception(result['message']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Modelo de treino atualizado com sucesso!'
                : 'Modelo de treino criado com sucesso!'),
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
            content: Text('Erro ao salvar modelo: $e'),
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
    final isEditing = widget.templateToEdit != null;

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Modelo de Treino' : 'Novo Modelo de Treino',
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
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText:
                            'Nome do Treino (ex: Treino de Musculação Masculino)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
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
                            maxLines: 8,
                            decoration: const InputDecoration(
                              labelText:
                                  'Descreva aqui o treino a ser realizado (texto/imagem)...',
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
                              onPressed: _saveTemplate,
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
                                'Confirmar',
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
