import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import '../../../services/physical_assessment_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/user_service.dart';
import '../../../config/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/searchable_selection.dart';
import '../../../models/user_role.dart';

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

  // Novas medidas e dobras cutâneas
  final _shoulderController = TextEditingController();
  final _rightForearmController = TextEditingController();
  final _leftForearmController = TextEditingController();
  final _skinfoldChestController = TextEditingController();
  final _skinfoldAbdomenController = TextEditingController();
  final _skinfoldThighController = TextEditingController();
  final _skinfoldCalfController = TextEditingController();
  final _skinfoldTricepsController = TextEditingController();
  final _skinfoldBicepsController = TextEditingController();
  final _skinfoldSubscapularController = TextEditingController();
  final _skinfoldSuprailiacController = TextEditingController();
  final _skinfoldMidaxillaryController = TextEditingController();
  final _workoutFocusController = TextEditingController();

  DateTime _assessmentDate = DateTime.now();
  DateTime? _studentBirthDate;

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
    _shoulderController.text = report['shoulder']?.toString() ?? '';
    _rightForearmController.text = report['right_forearm']?.toString() ?? '';
    _leftForearmController.text = report['left_forearm']?.toString() ?? '';
    _skinfoldChestController.text = report['skinfold_chest']?.toString() ?? '';
    _skinfoldAbdomenController.text =
        report['skinfold_abdomen']?.toString() ?? '';
    _skinfoldThighController.text = report['skinfold_thigh']?.toString() ?? '';
    _skinfoldCalfController.text = report['skinfold_calf']?.toString() ?? '';
    _skinfoldTricepsController.text =
        report['skinfold_triceps']?.toString() ?? '';
    _skinfoldBicepsController.text =
        report['skinfold_biceps']?.toString() ?? '';
    _skinfoldSubscapularController.text =
        report['skinfold_subscapular']?.toString() ?? '';
    _skinfoldSuprailiacController.text =
        report['skinfold_suprailiac']?.toString() ?? '';
    _skinfoldMidaxillaryController.text =
        report['skinfold_midaxillary']?.toString() ?? '';
    _workoutFocusController.text = report['workout_focus'] ?? '';
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await UserService.getStudentsForStaff();
      setState(() {
        _students = students;
        _isLoading = false;

        // Puxar data de nascimento se for edição
        if (widget.reportToEdit != null && _selectedStudentId != null) {
          final st = _students.firstWhere((s) => s['id'] == _selectedStudentId,
              orElse: () => {});
          if (st['birth_date'] != null) {
            _studentBirthDate = DateTime.tryParse(st['birth_date']);
          }
        }
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
    _shoulderController.dispose();
    _rightForearmController.dispose();
    _leftForearmController.dispose();
    _skinfoldChestController.dispose();
    _skinfoldAbdomenController.dispose();
    _skinfoldThighController.dispose();
    _skinfoldCalfController.dispose();
    _skinfoldTricepsController.dispose();
    _skinfoldBicepsController.dispose();
    _skinfoldSubscapularController.dispose();
    _skinfoldSuprailiacController.dispose();
    _skinfoldMidaxillaryController.dispose();
    _workoutFocusController.dispose();
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
      // Atualizar data de nascimento se necessário
      if (_studentBirthDate != null && _selectedStudentId != null) {
        try {
          await SupabaseService.client.from('users_alunos').update({
            'dt_nascimento': _studentBirthDate!.toIso8601String().split('T')[0]
          }).eq('id', _selectedStudentId!);
        } catch (e) {
          debugPrint('Erro ao salvar dt_nascimento: $e');
        }
      }

      if (widget.reportToEdit == null) {
        // Create
        await PhysicalAssessmentService.createAssessment(
          studentId: _selectedStudentId!,
          date: _assessmentDate,
          weight: double.tryParse(_weightController.text),
          height: double.tryParse(_heightController.text),
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
          shoulder: double.tryParse(_shoulderController.text),
          rightForearm: double.tryParse(_rightForearmController.text),
          leftForearm: double.tryParse(_leftForearmController.text),
          skinfoldChest: double.tryParse(_skinfoldChestController.text),
          skinfoldAbdomen: double.tryParse(_skinfoldAbdomenController.text),
          skinfoldThigh: double.tryParse(_skinfoldThighController.text),
          skinfoldCalf: double.tryParse(_skinfoldCalfController.text),
          skinfoldTriceps: double.tryParse(_skinfoldTricepsController.text),
          skinfoldBiceps: double.tryParse(_skinfoldBicepsController.text),
          skinfoldSubscapular:
              double.tryParse(_skinfoldSubscapularController.text),
          skinfoldSuprailiac:
              double.tryParse(_skinfoldSuprailiacController.text),
          skinfoldMidaxillary:
              double.tryParse(_skinfoldMidaxillaryController.text),
          workoutFocus: _workoutFocusController.text,
        );
      } else {
        // Update
        await PhysicalAssessmentService.updateAssessment(
          id: widget.reportToEdit!['id'],
          date: _assessmentDate,
          weight: double.tryParse(_weightController.text),
          height: double.tryParse(_heightController.text),
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
          shoulder: double.tryParse(_shoulderController.text),
          rightForearm: double.tryParse(_rightForearmController.text),
          leftForearm: double.tryParse(_leftForearmController.text),
          skinfoldChest: double.tryParse(_skinfoldChestController.text),
          skinfoldAbdomen: double.tryParse(_skinfoldAbdomenController.text),
          skinfoldThigh: double.tryParse(_skinfoldThighController.text),
          skinfoldCalf: double.tryParse(_skinfoldCalfController.text),
          skinfoldTriceps: double.tryParse(_skinfoldTricepsController.text),
          skinfoldBiceps: double.tryParse(_skinfoldBicepsController.text),
          skinfoldSubscapular:
              double.tryParse(_skinfoldSubscapularController.text),
          skinfoldSuprailiac:
              double.tryParse(_skinfoldSuprailiacController.text),
          skinfoldMidaxillary:
              double.tryParse(_skinfoldMidaxillaryController.text),
          workoutFocus: _workoutFocusController.text,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.reportToEdit == null
                ? 'Avaliação criada com sucesso!'
                : 'Avaliação atualizada!'),
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
      final role = await AuthService.getCurrentUserRole();

      String professionalLabel = 'Nutricionista';
      String professionalName = userData?['name'] ?? 'Nutricionista';

      if (role == UserRole.admin) {
        professionalLabel = 'Academia';
        professionalName =
            userData?['academia'] ?? userData?['name'] ?? 'Academia';
      } else if (role == UserRole.trainer) {
        professionalLabel = 'Personal Trainer';
      }

      final printData = {
        'student_name': studentName,
        'professional_name': professionalName,
        'professional_label': professionalLabel,
        'assessment_date': widget.reportToEdit!['assessment_date'],
        'weight': widget.reportToEdit!['weight'],
        'height': widget.reportToEdit!['height'],
        'body_fat': widget.reportToEdit!['body_fat'],
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
        'shoulder': widget.reportToEdit!['shoulder'],
        'right_forearm': widget.reportToEdit!['right_forearm'],
        'left_forearm': widget.reportToEdit!['left_forearm'],
        'skinfold_chest': widget.reportToEdit!['skinfold_chest'],
        'skinfold_abdomen': widget.reportToEdit!['skinfold_abdomen'],
        'skinfold_thigh': widget.reportToEdit!['skinfold_thigh'],
        'skinfold_calf': widget.reportToEdit!['skinfold_calf'],
        'skinfold_triceps': widget.reportToEdit!['skinfold_triceps'],
        'skinfold_biceps': widget.reportToEdit!['skinfold_biceps'],
        'skinfold_subscapular': widget.reportToEdit!['skinfold_subscapular'],
        'skinfold_suprailiac': widget.reportToEdit!['skinfold_suprailiac'],
        'skinfold_midaxillary': widget.reportToEdit!['skinfold_midaxillary'],
        'workout_focus': widget.reportToEdit!['workout_focus'],
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
          widget.reportToEdit == null ? 'Nova Avaliação' : 'Editar Avaliação',
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
                        if (widget.reportToEdit == null &&
                            _students.isNotEmpty) ...[
                          SearchableSelection<Map<String, dynamic>>(
                            label: 'Selecione o Aluno',
                            value: _selectedStudentId != null
                                ? _students.firstWhere(
                                    (s) => s['id'] == _selectedStudentId,
                                    orElse: () => {})
                                : null,
                            items: _students,
                            labelBuilder: (s) =>
                                s['nome'] ?? s['name'] ?? 'Sem Nome',
                            onChanged: (val) {
                              setState(() {
                                _selectedStudentId = val?['id'];
                                // Puxar data de nascimento ao selecionar
                                if (val != null && val['birth_date'] != null) {
                                  _studentBirthDate =
                                      DateTime.tryParse(val['birth_date']);
                                } else {
                                  _studentBirthDate = null;
                                }
                              });
                            },
                          ),
                        ] else if (widget.reportToEdit != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person, color: Colors.grey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _students.firstWhere(
                                          (s) => s['id'] == _selectedStudentId,
                                          orElse: () =>
                                              {'nome': 'Carregando...'},
                                        )['nome'] ??
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
                        ],

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

                        // Renderizar data de nascimento do aluno selecionado
                        if (_selectedStudentId != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _studentBirthDate ?? DateTime.now(),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                  builder: (context, child) => Theme(
                                    data: ThemeData.light().copyWith(
                                      colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF2A9D8F)),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (date != null) {
                                  setState(() => _studentBirthDate = date);
                                }
                              },
                              child: InputDecorator(
                                decoration:
                                    _inputDecoration('Data de Nascimento'),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _studentBirthDate != null
                                          ? DateFormat('dd/MM/yyyy')
                                              .format(_studentBirthDate!)
                                          : 'Não informada',
                                      style: GoogleFonts.lato(fontSize: 16),
                                    ),
                                    const Icon(Icons.edit_calendar, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        _buildSectionTitle('Dados Físicos:'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _heightController, 'Estatura')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _shoulderController, 'Ombro')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _chestController, 'Tórax')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _waistController, 'Cintura')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _abdomenController, 'Abdômen')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _hipsController, 'Quadril')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _rightArmController, 'Mesoumeral Dir.')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _leftArmController, 'Mesoumeral Esq.')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _rightForearmController,
                                    'Ante-Braço Dir.')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _leftForearmController, 'Ante-Braço Esq.')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _rightThighController, 'Mesofemural Dir.')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _leftThighController, 'Mesofemural Esq.')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _rightCalfController, 'Perna Dir.')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _leftCalfController, 'Perna Esq.')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _weightController, 'Peso')),
                            const SizedBox(width: 16),
                            Expanded(child: Container()), // Spacer
                          ],
                        ),

                        const SizedBox(height: 24),
                        _buildSectionTitle(
                            'Avaliação do %G (Pollock 3 ou 7 Dobras):'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _skinfoldChestController, 'Peitoral')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _skinfoldAbdomenController, 'Abdômem')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _skinfoldThighController, 'Coxa')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _skinfoldCalfController, 'Perna')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _skinfoldTricepsController, 'Tríceps')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _skinfoldBicepsController, 'Bíceps')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _skinfoldSubscapularController,
                                    'Subscapular')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildNumberField(
                                    _skinfoldSuprailiacController,
                                    'Suprailíaca')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _skinfoldMidaxillaryController,
                                    'Axiliar Média')),
                            const SizedBox(width: 16),
                            Expanded(child: Container()), // Spacer
                          ],
                        ),

                        const SizedBox(height: 24),
                        _buildSectionTitle('Resultado:'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: _buildNumberField(
                                    _bodyFatController, '%G =')),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _workoutFocusController,
                                decoration: _inputDecoration('Foco do Treino'),
                              ),
                            ),
                          ],
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
          if (_isPrinting) ...[
            Container(
              color: Colors.black.withAlpha(76), // 0.3 * 255 = 76.5
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
