import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../../services/user_service.dart';
import '../../services/appointment_service.dart';
import '../../models/user_role.dart';
import '../../widgets/searchable_selection.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class ScheduleAssessmentScreen extends StatefulWidget {
  final Map<String, dynamic>? appointmentToEdit;

  const ScheduleAssessmentScreen({super.key, this.appointmentToEdit});

  @override
  State<ScheduleAssessmentScreen> createState() =>
      _ScheduleAssessmentScreenState();
}

class _ScheduleAssessmentScreenState extends State<ScheduleAssessmentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;

  // Estado do Formulário
  bool _isStudent = true; // True = Aluno cadastrado, False = Visitante
  String? _selectedStudentId;
  final _visitorNameController = TextEditingController();
  final _visitorPhoneController = TextEditingController();

  DateTime _selectedDate =
      DateTime.now().add(const Duration(days: 1)); // Amanhã
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  // Dados carregados
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _nutricionistas = [];
  List<Map<String, dynamic>> _trainers = [];

  // Seleção de Profissionais (IDs)
  String? _selectedNutriId;
  String? _selectedTrainerId;

  // Status (Novo)
  String _status = 'scheduled';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _visitorNameController.dispose();
    _visitorPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Carregar Alunos
      final students = await UserService.getUsersByRole(UserRole.student);

      // Carregar Profissionais
      final pros = await AppointmentService.getAvailableProfessionals();

      final nutris =
          pros.where((p) => p['type_code'] == 'nutritionist').toList();
      final trainers = pros.where((p) => p['type_code'] == 'trainer').toList();

      if (mounted) {
        setState(() {
          _students = students;
          _nutricionistas = nutris;
          _trainers = trainers;
          _isLoading = false;
        });

        // Se for edição, preencher dados DEPOIS de carregar as listas
        if (widget.appointmentToEdit != null) {
          _populateForEdit();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  void _populateForEdit() {
    final appt = widget.appointmentToEdit!;

    // Data e Hora
    final scheduledAt = DateTime.parse(appt['scheduled_at']).toLocal();
    _selectedDate = scheduledAt;
    _selectedTime = TimeOfDay.fromDateTime(scheduledAt);

    // Aluno vs Visitante
    if (appt['student_id'] != null) {
      _isStudent = true;
      _selectedStudentId = appt['student_id'];
    } else {
      _isStudent = false;
      _visitorNameController.text = appt['visitor_name'] ?? '';
      _visitorPhoneController.text = appt['visitor_phone'] ?? '';
    }

    // Profissionais
    final List<dynamic> profIds = appt['professional_ids'] ?? [];

    // Tentar encontrar quais desses IDs são nutris ou trainers
    for (var id in profIds) {
      // É nutri?
      if (_nutricionistas.any((n) => n['id'] == id)) {
        _selectedNutriId = id;
      }
      // É trainer?
      if (_trainers.any((t) => t['id'] == id)) {
        _selectedTrainerId = id;
      }
    }

    // Status
    _status = appt['status'] ?? 'scheduled';
  }

  Future<void> _handleSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isStudent && _selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um aluno')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Combinar IDs selecionados
    final List<String> professionalIds = [];
    if (_selectedNutriId != null) professionalIds.add(_selectedNutriId!);
    if (_selectedTrainerId != null) professionalIds.add(_selectedTrainerId!);

    // Combinar Data e Hora
    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    Map<String, dynamic> result;

    if (widget.appointmentToEdit != null) {
      // ATUALIZAR
      try {
        await AppointmentService.updateAppointment(
          id: widget.appointmentToEdit!['id'],
          studentId: _isStudent ? _selectedStudentId : null,
          visitorName: _isStudent ? null : _visitorNameController.text.trim(),
          visitorPhone: _isStudent ? null : _visitorPhoneController.text.trim(),
          professionalIds: professionalIds,
          scheduledAt: scheduledAt.toUtc(),
          status: _status, // Novo campo
        );
        result = {'success': true, 'message': 'Agendamento atualizado!'};
      } catch (e) {
        result = {'success': false, 'message': e.toString()};
      }
    } else {
      // CRIAR
      result = await AppointmentService.createAppointment(
        studentId: _isStudent ? _selectedStudentId : null,
        visitorName: _isStudent ? null : _visitorNameController.text.trim(),
        visitorPhone: _isStudent ? null : _visitorPhoneController.text.trim(),
        professionalIds: professionalIds,
        scheduledAt: scheduledAt.toUtc(),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message']), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Retorna true para atualizar a lista
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message']), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.appointmentToEdit != null;

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Agendamento' : 'Agendar Avaliação',
          style: GoogleFonts.cinzel(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.secondaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Quem será avaliado?
                    Text(
                      'QUEM SERÁ AVALIADO?',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryText,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Switch Aluno / Visitante
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.lightGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isStudent = true),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isStudent
                                      ? AppTheme.primaryText
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Aluno',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: _isStudent
                                            ? Colors.white
                                            : AppTheme.secondaryText,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isStudent = false),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isStudent
                                      ? AppTheme.primaryText
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Novo / Visitante',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: !_isStudent
                                            ? Colors.white
                                            : AppTheme.secondaryText,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Inputs Condicionais
                    if (_isStudent) ...[
                      SearchableSelection<Map<String, dynamic>>(
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
                            setState(() => _selectedStudentId = val['id']);
                        },
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _visitorNameController,
                        decoration: InputDecoration(
                          labelText: 'Nome Completo',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppTheme.lightGrey,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Informe o nome' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _visitorPhoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          MaskTextInputFormatter(
                            mask: '(##) #####-####',
                            filter: {"#": RegExp(r'[0-9]')},
                            type: MaskAutoCompletionType.lazy,
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Telefone',
                          hintText: '(XX) XXXXX-XXXX',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppTheme.lightGrey,
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: (value) =>
                            value!.length < 14 ? 'Telefone inválido' : null,
                      ),
                    ],

                    const SizedBox(height: 32),

                    // 2. Profissional Responsável
                    Text(
                      'PROFISSIONAL RESPONSÁVEL',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryText,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nutricionista Dropdown
                    SearchableSelection<Map<String, dynamic>>(
                      label: 'Nutricionista (Opcional)',
                      value: _selectedNutriId != null
                          ? _nutricionistas.firstWhere(
                              (n) => n['id'] == _selectedNutriId,
                              orElse: () => {})
                          : null,
                      items: [
                        {'id': null, 'name': 'Nenhum'},
                        ..._nutricionistas
                      ],
                      labelBuilder: (n) => n['name'] ?? 'Sem Nome',
                      hintText: 'Buscar nutricionista...',
                      onChanged: (val) {
                        setState(() => _selectedNutriId = val?['id']);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Personal Dropdown
                    SearchableSelection<Map<String, dynamic>>(
                      label: 'Personal Trainer (Opcional)',
                      value: _selectedTrainerId != null
                          ? _trainers.firstWhere(
                              (t) => t['id'] == _selectedTrainerId,
                              orElse: () => {})
                          : null,
                      items: [
                        {'id': null, 'name': 'Nenhum'},
                        ..._trainers
                      ],
                      labelBuilder: (t) => t['name'] ?? 'Sem Nome',
                      hintText: 'Buscar personal...',
                      onChanged: (val) {
                        setState(() => _selectedTrainerId = val?['id']);
                      },
                    ),

                    const SizedBox(height: 32),

                    // 3. Data e Hora
                    Text(
                      'DATA E HORA',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryText,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.borderGrey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Data',
                                      style: TextStyle(
                                          color: AppTheme.secondaryText,
                                          fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                          DateFormat('dd/MM/yyyy')
                                              .format(_selectedDate),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: _pickTime,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.borderGrey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Horário',
                                      style: TextStyle(
                                          color: AppTheme.secondaryText,
                                          fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 20),
                                      const SizedBox(width: 8),
                                      Text(_selectedTime.format(context),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Campo de Status (Apenas na edição)
                    if (widget.appointmentToEdit != null) ...[
                      Text(
                        'SITUAÇÃO',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryText,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppTheme.lightGrey,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'scheduled', child: Text('Aguardando')),
                          DropdownMenuItem(
                              value: 'completed', child: Text('Concluída')),
                          DropdownMenuItem(
                              value: 'cancelled', child: Text('Cancelada')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Botão Agendar
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _handleSchedule,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryText,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isEditing
                              ? 'ATUALIZAR AGENDAMENTO'
                              : 'CONFIRMAR AGENDAMENTO',
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
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
}
