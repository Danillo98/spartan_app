import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import '../../../services/physical_assessment_service.dart';
import '../../../services/user_service.dart';
import '../../../config/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/searchable_selection.dart';

class CreateEditReportScreen extends StatefulWidget {
  final Map<String, dynamic>? reportToEdit;

  const CreateEditReportScreen({super.key, this.reportToEdit});

  @override
  State<CreateEditReportScreen> createState() => _CreateEditReportScreenState();
}

class _CreateEditReportScreenState extends State<CreateEditReportScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPrinting = false;

  // Seleção de Aluno
  List<Map<String, dynamic>> _students = [];
  String? _selectedStudentId;

  // Controllers
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _neckController = TextEditingController();
  final _chestController = TextEditingController();
  final _waistController = TextEditingController();
  final _abdomenController = TextEditingController();
  final _hipsController = TextEditingController();
  final _rightArmController = TextEditingController();
  final _leftArmController = TextEditingController();
  final _rightThighController = TextEditingController();
  final _leftThighController = TextEditingController();
  final _rightCalfController = TextEditingController();
  final _leftCalfController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _muscleMassController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _assessmentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadStudents();
    if (widget.reportToEdit != null) {
      _fillData(widget.reportToEdit!);
    }
  }

  void _fillData(Map<String, dynamic> report) {
    _selectedStudentId = report['student_id'];
    _assessmentDate = DateTime.parse(report['assessment_date']);

    _weightController.text = report['weight']?.toString() ?? '';
    _heightController.text = report['height']?.toString() ?? '';
    _neckController.text = report['neck']?.toString() ?? '';
    _chestController.text = report['chest']?.toString() ?? '';
    _waistController.text = report['waist']?.toString() ?? '';
    _abdomenController.text = report['abdomen']?.toString() ?? '';
    _hipsController.text = report['hips']?.toString() ?? '';
    _rightArmController.text = report['right_arm']?.toString() ?? '';
    _leftArmController.text = report['left_arm']?.toString() ?? '';
    _rightThighController.text = report['right_thigh']?.toString() ?? '';
    _leftThighController.text = report['left_thigh']?.toString() ?? '';
    _rightCalfController.text = report['right_calf']?.toString() ?? '';
    _leftCalfController.text = report['left_calf']?.toString() ?? '';
    _bodyFatController.text = report['body_fat']?.toString() ?? '';
    _muscleMassController.text = report['muscle_mass']?.toString() ?? '';
    _notesController.text = report['notes'] ?? '';
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await UserService.getStudentsForStaff();
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Opcional: mostrar erro
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _neckController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _abdomenController.dispose();
    _hipsController.dispose();
    _rightArmController.dispose();
    _leftArmController.dispose();
    _rightThighController.dispose();
    _leftThighController.dispose();
    _rightCalfController.dispose();
    _leftCalfController.dispose();
    _bodyFatController.dispose();
    _muscleMassController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, verifique os campos obrigatórios')),
      );
      return;
    }

    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um aluno')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.reportToEdit == null) {
        // Create
        await PhysicalAssessmentService.createAssessment(
          studentId: _selectedStudentId!,
          date: _assessmentDate,
          weight: double.tryParse(_weightController.text),
          height: double.tryParse(_heightController.text),
          neck: double.tryParse(_neckController.text),
          chest: double.tryParse(_chestController.text),
          waist: double.tryParse(_waistController.text),
          abdomen: double.tryParse(_abdomenController.text),
          hips: double.tryParse(_hipsController.text),
          rightArm: double.tryParse(_rightArmController.text),
          leftArm: double.tryParse(_leftArmController.text),
          rightThigh: double.tryParse(_rightThighController.text),
          leftThigh: double.tryParse(_leftThighController.text),
          rightCalf: double.tryParse(_rightCalfController.text),
          leftCalf: double.tryParse(_leftCalfController.text),
          bodyFat: double.tryParse(_bodyFatController.text),
          muscleMass: double.tryParse(_muscleMassController.text),
          notes: _notesController.text,
        );
      } else {
        // Update
        await PhysicalAssessmentService.updateAssessment(
          id: widget.reportToEdit!['id'],
          date: _assessmentDate,
          weight: double.tryParse(_weightController.text),
          height: double.tryParse(_heightController.text),
          neck: double.tryParse(_neckController.text),
          chest: double.tryParse(_chestController.text),
          waist: double.tryParse(_waistController.text),
          abdomen: double.tryParse(_abdomenController.text),
          hips: double.tryParse(_hipsController.text),
          rightArm: double.tryParse(_rightArmController.text),
          leftArm: double.tryParse(_leftArmController.text),
          rightThigh: double.tryParse(_rightThighController.text),
          leftThigh: double.tryParse(_leftThighController.text),
          rightCalf: double.tryParse(_rightCalfController.text),
          leftCalf: double.tryParse(_leftCalfController.text),
          bodyFat: double.tryParse(_bodyFatController.text),
          muscleMass: double.tryParse(_muscleMassController.text),
          notes: _notesController.text,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.reportToEdit == null
                ? 'Relatório criado com sucesso!'
                : 'Relatório atualizado!'),
            backgroundColor: const Color(0xFF2A9D8F),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openPrintPage() async {
    setState(() => _isPrinting = true);
    try {
      if (widget.reportToEdit == null) return;

      // Get student name (might be in reportToEdit or _students list)
      String studentName = 'Não informado';
      if (_selectedStudentId != null) {
        // Try finding in the loaded students list first
        final student = _students
            .firstWhere((s) => s['id'] == _selectedStudentId, orElse: () => {});

        if (student.isNotEmpty && student['name'] != null) {
          studentName = student['name'];
        } else {
          // Fallback to the report object
          studentName = widget.reportToEdit?['users_alunos']?['nome'] ??
              widget.reportToEdit?['student']?['name'] ??
              'Aluno';
        }
      }

      final userData = await AuthService.getCurrentUserData();
      final nutritionistName = userData?['name'] ?? 'Nutricionista';

      final printData = {
        'student_name': studentName,
        'nutritionist_name': nutritionistName,
        'assessment_date': widget.reportToEdit!['assessment_date'],
        'weight': widget.reportToEdit!['weight'],
        'height': widget.reportToEdit!['height'],
        'body_fat': widget.reportToEdit!['body_fat'],
        'muscle_mass': widget.reportToEdit!['muscle_mass'],
        'neck': widget.reportToEdit!['neck'],
        'chest': widget.reportToEdit!['chest'],
        'waist': widget.reportToEdit!['waist'],
        'abdomen': widget.reportToEdit!['abdomen'],
        'hips': widget.reportToEdit!['hips'],
        'right_arm': widget.reportToEdit!['right_arm'],
        'left_arm': widget.reportToEdit!['left_arm'],
        'right_thigh': widget.reportToEdit!['right_thigh'],
        'left_thigh': widget.reportToEdit!['left_thigh'],
        'right_calf': widget.reportToEdit!['right_calf'],
        'left_calf': widget.reportToEdit!['left_calf'],
        'notes': widget.reportToEdit!['notes'],
      };

      final jsonData = jsonEncode(printData);
      final blob = html.Blob([jsonData], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final baseUrl = html.window.location.origin;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final printUrl =
          '$baseUrl/print-evolution.html?v=$timestamp&dataUrl=$url';

      if (mounted) setState(() => _isPrinting = false);

      html.window.open(printUrl, '_blank');

      Future.delayed(const Duration(seconds: 20), () {
        html.Url.revokeObjectUrl(url);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir impressão: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          widget.reportToEdit == null ? 'Novo Relatório' : 'Editar Relatório',
          style: GoogleFonts.cinzel(
              fontWeight: FontWeight.bold, color: AppTheme.primaryText),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.secondaryText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.reportToEdit != null)
            IconButton(
              icon:
                  const Icon(Icons.print_rounded, color: AppTheme.primaryText),
              onPressed: (_isLoading || _isPrinting) ? null : _openPrintPage,
              tooltip: 'Imprimir Avaliação',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Aluno & Data'),
                        const SizedBox(height: 16),
                        // Dropdown Aluno replaced with SearchableSelection
                        widget.reportToEdit == null
                            ? SearchableSelection<Map<String, dynamic>>(
                                label: 'Selecione o Aluno',
                                value: _selectedStudentId != null
                                    ? _students.firstWhere(
                                        (s) => s['id'] == _selectedStudentId,
                                        orElse: () => {})
                                    : null,
                                items: _students,
                                labelBuilder: (s) => s['name'] ?? 'Sem Nome',
                                hintText: 'Buscar aluno...',
                                onChanged: (val) {
                                  if (val != null)
                                    setState(
                                        () => _selectedStudentId = val['id']);
                                },
                              )
                            : Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person,
                                        color: Colors.grey),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _students.firstWhere(
                                              (s) =>
                                                  s['id'] == _selectedStudentId,
                                              orElse: () =>
                                                  {'name': 'Carregando...'},
                                            )['name'] ??
                                            'Aluno não encontrado',
                                        style: GoogleFonts.lato(
                                          fontSize: 16,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                        const SizedBox(height: 16),
                        // Date Picker
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _assessmentDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF2A9D8F),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) {
                              setState(() => _assessmentDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: _inputDecoration('Data da Avaliação'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('dd/MM/yyyy')
                                    .format(_assessmentDate)),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        _buildSectionTitle('Dados Físicos'),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _weightController, 'Peso (kg)',
                                    required: true)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _heightController, 'Altura (cm)',
                                    required: true)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _bodyFatController, '% Gordura')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _muscleMassController, '% Massa Muscular')),
                          ],
                        ),

                        const SizedBox(height: 24),
                        _buildSectionTitle('Circunferências (cm)'),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _neckController, 'Pescoço')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _chestController, 'Peitoral')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _waistController, 'Cintura')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _abdomenController, 'Abdômen')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _hipsController, 'Quadril')),
                            const SizedBox(width: 16),
                            Expanded(child: Container()), // Spacer
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Text('Membros Superiores',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _rightArmController, 'Braço Dir.')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _leftArmController, 'Braço Esq.')),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Text('Membros Inferiores',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _rightThighController, 'Coxa Dir.')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _leftThighController, 'Coxa Esq.')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _rightCalfController, 'Panturrilha Dir.')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _leftCalfController, 'Panturrilha Esq.')),
                          ],
                        ),

                        const SizedBox(height: 24),
                        _buildSectionTitle('Observações'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 4,
                          decoration:
                              _inputDecoration('Notas adicionais, metas, etc.'),
                        ),

                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A9D8F),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSaving
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('SALVAR RELATÓRIO',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
          if (_isPrinting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF2A9D8F)),
                        SizedBox(height: 16),
                        Text('Gerando PDF...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label,
      {bool required = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      decoration: _inputDecoration(label),
      validator: required
          ? (val) => (val == null || val.isEmpty) ? 'Obrigatório' : null
          : null,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.lato(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF2A9D8F),
      ),
    );
  }
}
