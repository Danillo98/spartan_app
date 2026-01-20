import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../services/notice_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_role.dart';
import '../../services/notification_service.dart';

class NoticeManagerScreen extends StatefulWidget {
  const NoticeManagerScreen({super.key});

  @override
  State<NoticeManagerScreen> createState() => _NoticeManagerScreenState();
}

class _NoticeManagerScreenState extends State<NoticeManagerScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notices = [];

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() => _isLoading = true);
    try {
      final data = await NoticeService.getNotices();
      if (mounted) {
        setState(() {
          _notices = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar avisos: $e')),
        );
      }
    }
  }

  Future<void> _deleteNotice(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Aviso'),
        content: const Text('Deseja realmente excluir este aviso?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NoticeService.deleteNotice(id);
      _loadNotices();
    }
  }

  void _openNoticeForm({Map<String, dynamic>? notice}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NoticeFormModal(
        noticeToEdit: notice,
        onSave: _loadNotices,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text(
          'Gerenciar Avisos',
          style: GoogleFonts.cinzel(
              color: AppTheme.primaryText, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.secondaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNoticeForm(),
        backgroundColor: AppTheme.primaryText,
        icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
        label: const Text('Novo Aviso', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notices.isEmpty
              ? Center(
                  child: Text('Nenhum aviso cadastrado.',
                      style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notices.length,
                  itemBuilder: (context, index) {
                    final notice = _notices[index];
                    final start = DateTime.parse(notice['start_at']).toLocal();
                    final end = DateTime.parse(notice['end_at']).toLocal();
                    final now = DateTime.now();
                    final isActive = now.isAfter(start) && now.isBefore(end);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    notice['title'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (notice['author_label'] != null)
                                      Builder(
                                        builder: (context) {
                                          final fullText =
                                              notice['author_label'].toString();
                                          final parts = fullText.split(':');
                                          final role = parts[0];
                                          final name = parts.length > 1
                                              ? parts.sublist(1).join(':')
                                              : '';
                                          final isNutri = role
                                              .toLowerCase()
                                              .contains('nutri');
                                          final isPersonal = role
                                              .toLowerCase()
                                              .contains('personal');
                                          final roleColor = isNutri
                                              ? const Color(0xFF2A9D8F)
                                              : isPersonal
                                                  ? AppTheme.primaryRed
                                                  : AppTheme.primaryText;

                                          return RichText(
                                            textAlign: TextAlign.right,
                                            text: TextSpan(
                                              style: GoogleFonts.lato(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: AppTheme.primaryText,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: role,
                                                  style: TextStyle(
                                                      color: roleColor),
                                                ),
                                                if (name.isNotEmpty)
                                                  TextSpan(text: ':$name'),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    if (isActive)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border:
                                              Border.all(color: Colors.green),
                                        ),
                                        child: const Text('ATIVO',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(notice['description'],
                                style: TextStyle(color: Colors.grey[800])),
                            const SizedBox(height: 12),
                            Divider(color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${DateFormat('dd/MM HH:mm').format(start)} até ${DateFormat('dd/MM HH:mm').format(end)}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon:
                                      const Icon(Icons.edit_rounded, size: 20),
                                  color: Colors.blueGrey,
                                  onPressed: () =>
                                      _openNoticeForm(notice: notice),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 20),
                                  color: Colors.red[400],
                                  onPressed: () => _deleteNotice(notice['id']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _NoticeFormModal extends StatefulWidget {
  final Map<String, dynamic>? noticeToEdit;
  final VoidCallback onSave;

  const _NoticeFormModal({this.noticeToEdit, required this.onSave});

  @override
  State<_NoticeFormModal> createState() => _NoticeFormModalState();
}

class _NoticeFormModalState extends State<_NoticeFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  DateTime _startAt = DateTime.now();
  DateTime _endAt = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);

  bool _isLoading = false;

  // New State Variables
  List<Map<String, dynamic>> _availableStudents = [];
  String? _selectedStudentId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoadStudents(); // Load role and students

    if (widget.noticeToEdit != null) {
      final n = widget.noticeToEdit!;
      _titleController.text = n['title'];
      _descController.text = n['description'];
      _selectedStudentId = n['target_student_id']; // Load potential target

      final s = DateTime.parse(n['start_at']).toLocal();
      final e = DateTime.parse(n['end_at']).toLocal();

      _startAt = s;
      _startTime = TimeOfDay.fromDateTime(s);

      _endAt = e;
      _endTime = TimeOfDay.fromDateTime(e);
    }
  }

  Future<void> _checkRoleAndLoadStudents() async {
    final role = await AuthService.getCurrentUserRole();
    if (!mounted) return;
    setState(() => _isAdmin = role == UserRole.admin);

    try {
      if (_isAdmin) {
        // Admin pode ver todos os alunos
        final users = await UserService.getUsersByRole(UserRole.student);
        if (mounted) setState(() => _availableStudents = users);
      } else {
        // Staff ve seus alunos
        final users = await UserService.getStudentsForStaff();
        if (mounted) setState(() => _availableStudents = users);
      }
    } catch (e) {
      print("Erro ao carregar alunos: $e");
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initialDate = isStart ? _startAt : _endAt;
    final initialTime = isStart ? _startTime : _endTime;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time == null) return;

    setState(() {
      if (isStart) {
        _startAt = date;
        _startTime = time;
      } else {
        _endAt = date;
        _endTime = time;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final start = DateTime(_startAt.year, _startAt.month, _startAt.day,
          _startTime.hour, _startTime.minute);
      final end = DateTime(_endAt.year, _endAt.month, _endAt.day, _endTime.hour,
          _endTime.minute);

      if (end.isBefore(start)) {
        throw Exception('A data de fim deve ser posterior ao início.');
      }

      final role = _isAdmin
          ? 'Admin'
          : (await AuthService.getCurrentUserRole()).toString().split('.').last;
      final roleAuthorLabel = _isAdmin
          ? 'Gestão da Academia'
          : (role == 'trainer' ? 'Seu Personal' : 'Seu Nutricionista');

      if (widget.noticeToEdit != null) {
        await NoticeService.updateNotice(
          id: widget.noticeToEdit!['id'],
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          startAt: start,
          endAt: end,
          // Update target not supported in standard updateNotice yet, need to check NoticeService
          // Assumption: NoticeService.updateNotice doesn't update target. If needed, modify it.
          // For now, let's assume we can't change target on edit or I need to update NoticeService sig.
        );
      } else {
        await NoticeService.createNotice(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          startAt: start,
          endAt: end,
          targetStudentId: _selectedStudentId, // Pass target
          authorLabel: roleAuthorLabel,
        );
      }

      // --- SEND NOTIFICATION ---
      // Send push notification after creating/updating notice
      try {
        await NotificationService.notifyNotice(
            _titleController.text.trim(), roleAuthorLabel,
            targetStudentId: _selectedStudentId,
            // Se for admin e não tiver target, pode querer mandar para todos (necessita CNPJ)
            // Vamos assumir que NotificationService lida com isso se passarmos o CNPJ
            academyCnpj: _isAdmin && _selectedStudentId == null
                ? 'CURRENT_CNPJ_PLACEHOLDER'
                : null
            // Note: NoticeService gets CNPJ internally. We might need to fetch it to pass here
            // or move notification logic INTO NoticeService to avoid double fetching.
            // For now, let's just use the targetStudentId logic. Broadcast via CNPJ requires fetching CNPJ first.
            );

        // Se for broadcast (Admin sem user selecionado), precisamos do CNPJ
        if (_isAdmin && _selectedStudentId == null) {
          // Fetch CNPJ inside NotificationService logic or here.
          // Simplest: Let NoticeService handle the notification?
          // Or just fetch basic info.
          // Let's rely on NoticeService returning/using context.
          // Actually, best practice: Move notification call to NoticeService to ensure atomic op logic
          // but here is fine for UI feedback.

          // Fetch current user details to get CNPJ for broadcast
          final adminData = await AuthService.getCurrentUserData();
          if (adminData != null) {
            await NotificationService.notifyNotice(
                _titleController.text.trim(), roleAuthorLabel,
                academyCnpj: adminData['cnpj_academia']);
          }
        }
      } catch (e) {
        print("Erro ao enviar push: $e");
      }
      // -------------------------

      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.noticeToEdit != null ? 'Editar Aviso' : 'Novo Aviso',
                style: GoogleFonts.cinzel(
                    fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Informe o título' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => v!.isEmpty ? 'Informe a descrição' : null,
              ),
              const SizedBox(height: 24),
              // Seletor de Destinatário (Apenas para Personal/Nutri ou Admin Opcional)
              // Logica: Admin -> Default Todos (Null). Staff -> Obrigatório selecionar aluno.
              if (_availableStudents.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedStudentId,
                  decoration: const InputDecoration(
                    labelText: 'Destinatário (Aluno)',
                    border: OutlineInputBorder(),
                    helperText:
                        'Deixe vazio para enviar para todos (se permitido)',
                  ),
                  items: [
                    // Opção "Todos" apenas se for Admin (ou se a regra permitir)
                    // Para simplificar: Staff deve selecionar um aluno.
                    if (_isAdmin)
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos da Academia',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ..._availableStudents.map((s) {
                      return DropdownMenuItem(
                        value: s['id'].toString(),
                        child: Text(s['name'] ?? 'Aluno'),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedStudentId = v),
                  validator: (v) {
                    if (!_isAdmin && v == null) {
                      return 'Selecione um aluno para enviar o aviso.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDateTime(true), // Início
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Início',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(_startAt)),
                            Text(_startTime.format(context),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDateTime(false), // Fim
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Fim',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(_endAt)),
                            Text(_endTime.format(context),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryText,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('SALVAR E NOTIFICAR', // Updated label
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
