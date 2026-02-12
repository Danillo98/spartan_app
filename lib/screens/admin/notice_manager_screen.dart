import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../services/notice_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_role.dart';
import '../../services/notification_service.dart';
import '../../widgets/multi_searchable_selection.dart';

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

                    final targetRole = notice['target_role'] ?? 'all';
                    String targetLabel = 'Todos';
                    if (targetRole == 'student')
                      targetLabel = 'Alunos';
                    else if (targetRole == 'nutritionist')
                      targetLabel = 'Nutricionistas';
                    else if (targetRole == 'trainer') targetLabel = 'Personais';

                    // Verifica ids para display
                    var ids = notice['target_user_ids'];
                    // Retrocompatibilidade
                    if (ids == null) {
                      if (notice['target_user_id'] != null)
                        ids = [notice['target_user_id']];
                      else if (notice['target_student_id'] != null)
                        ids = [notice['target_student_id']];
                    }

                    final count = (ids is List) ? ids.length : 0;
                    final targetUser =
                        count > 0 ? ' ($count selecionados)' : ' (Todos)';

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
                                      Text(
                                        notice['author_label'],
                                        style: GoogleFonts.lato(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryText),
                                      ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      child: Text(
                                          'Para: $targetLabel$targetUser',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[800])),
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
  List<Map<String, dynamic>> _availableUsers = [];
  List<String> _selectedUserIds = []; // LISTA
  String _selectedTargetRole =
      'all'; // 'all', 'student', 'nutritionist', 'trainer'
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoadData();

    if (widget.noticeToEdit != null) {
      final n = widget.noticeToEdit!;
      _titleController.text = n['title'];
      _descController.text = n['description'];

      // Load Target Info
      _selectedTargetRole = n['target_role'] ?? 'student'; // Fallback legacy
      if (_selectedTargetRole == 'all' && n['target_student_id'] != null) {
        _selectedTargetRole = 'student'; // Legacy fix
      }

      // Load IDs
      if (n['target_user_ids'] != null) {
        _selectedUserIds = List<String>.from(n['target_user_ids']);
      } else if (n['target_user_id'] != null) {
        _selectedUserIds = [n['target_user_id']];
      } else if (n['target_student_id'] != null) {
        _selectedUserIds = [n['target_student_id']];
      }

      final s = DateTime.parse(n['start_at']).toLocal();
      final e = DateTime.parse(n['end_at']).toLocal();

      _startAt = s;
      _startTime = TimeOfDay.fromDateTime(s);

      _endAt = e;
      _endTime = TimeOfDay.fromDateTime(e);

      // Se já veio editando, precisamos carregar a lista do role selecionado
      if (_selectedTargetRole != 'all') {
        _loadUsersForRole(_selectedTargetRole);
      }
    }
  }

  Future<void> _checkRoleAndLoadData() async {
    final role = await AuthService.getCurrentUserRole();
    if (!mounted) return;
    setState(() => _isAdmin = role == UserRole.admin);

    if (!_isAdmin) {
      _selectedTargetRole = 'student';
      _loadUsersForRole('student');
    }
  }

  Future<void> _loadUsersForRole(String role) async {
    try {
      List<Map<String, dynamic>> users = [];
      if (role == 'student') {
        if (_isAdmin) {
          users = await UserService.getUsersByRole(UserRole.student);
        } else {
          users = await UserService.getStudentsForStaff();
        }
      } else if (role == 'nutritionist') {
        users = await UserService.getUsersByRole(UserRole.nutritionist);
      } else if (role == 'trainer') {
        users = await UserService.getUsersByRole(UserRole.trainer);
      }

      if (mounted) {
        setState(() {
          _availableUsers = users;
          // Clean invalid selection
          _selectedUserIds = _selectedUserIds
              .where((id) => users.any((u) => u['id'] == id))
              .toList();
        });
      }
    } catch (e) {
      print("Erro ao carregar usuários para role $role: $e");
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

      final myRoleStr =
          (await AuthService.getCurrentUserRole()).toString().split('.').last;

      final authorLabel = _isAdmin
          ? 'Administração da academia'
          : (myRoleStr == 'trainer' ? 'Seu Personal' : 'Seu Nutricionista');

      if (widget.noticeToEdit != null) {
        await NoticeService.updateNotice(
          id: widget.noticeToEdit!['id'],
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          startAt: start,
          endAt: end,
        );
      } else {
        await NoticeService.createNotice(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          startAt: start,
          endAt: end,
          targetRole: _selectedTargetRole,
          targetUserIds: _selectedUserIds.isEmpty ? null : _selectedUserIds,
          authorLabel: authorLabel,
        );
      }

      try {
        String? targetIdAcademia;
        if (_selectedUserIds.isEmpty) {
          final userData = await AuthService.getCurrentUserData();
          // Se for admin, o id_academia é o seu próprio id.
          // Se for nutri/personal, está no campo id_academia
          targetIdAcademia = userData?['id_academia'] ?? userData?['id'];
        }

        if (_selectedUserIds.isNotEmpty) {
          // Manda Push Direto (Batch se possível ou loop)
          // Usando o NotificationService.sendPush (assumindo que existe e aceita lista)
          // Se não existir, mandamos por tópico mesmo ou loop

          // Opção 1: Loop (Seguro)
          // for (var id in _selectedUserIds) {
          //    await NotificationService.notifyNotice(...)
          // }
          // Opção 2: Batch (Melhor) -> sendPush com targetPlayerIds (lista)
          // Assumindo que o NotificationService.sendPush do inicio da conversa (arquivo view_file 495) tem essa capacidade via OneSignal/Firebase.
          // Olhando o arquivo 495, ele tem sendNotification(title, body, [tokens]).
          // Mas aqui não temos tokens na mão.
          // Vamos usar a opção de "notifyNotice" modificada para aceitar Lista?
          // O usuário não pediu alteração no NotificationService, então vou usar um loop no notifyNotice para manter compatibilidade simples ou passar nulo e ele manda para todos.

          // Se selecionar alguns, mandamos loop para garantir entrega individual
          // SIMPLIFICAÇÃO: Se for muitos, isso pode demorar. Mas ok para MVP.
          for (var uid in _selectedUserIds) {
            await NotificationService.notifyNotice(
                _titleController.text.trim(), authorLabel,
                targetStudentId: uid);
          }
        } else {
          // Broadcast
          await NotificationService.notifyNotice(
            _titleController.text.trim(),
            authorLabel,
            idAcademia: targetIdAcademia,
          );
        }
      } catch (e) {
        print("Erro ao enviar push: $e");
      }

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
              if (_isAdmin) ...[
                DropdownButtonFormField<String>(
                  value: _selectedTargetRole,
                  decoration: const InputDecoration(
                    labelText: 'Perfil Alvo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('Todos (Geral)')),
                    DropdownMenuItem(value: 'student', child: Text('Aluno')),
                    DropdownMenuItem(
                        value: 'nutritionist', child: Text('Nutricionista')),
                    DropdownMenuItem(
                        value: 'trainer', child: Text('Personal Trainer')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedTargetRole = val;
                        _selectedUserIds = [];
                        _availableUsers = [];
                      });
                      if (val != 'all') {
                        _loadUsersForRole(val);
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (_selectedTargetRole != 'all') ...[
                MultiSearchableSelection<Map<String, dynamic>>(
                  label:
                      'Destinatários (${_getRoleLabel(_selectedTargetRole)})',
                  hintText: _selectedUserIds.isEmpty
                      ? 'Nenhum selecionado (Envia para TODOS)'
                      : '${_selectedUserIds.length} selecionados',
                  items: _availableUsers,
                  selectedItems: _availableUsers
                      .where((u) => _selectedUserIds.contains(u['id']))
                      .toList(),
                  idBuilder: (u) => u['id'].toString(),
                  labelBuilder: (u) => u['name'] ?? u['nome'] ?? 'Usuário',
                  onChanged: (selectedList) {
                    setState(() {
                      _selectedUserIds =
                          selectedList.map((u) => u['id'].toString()).toList();
                    });
                  },
                ),
                if (_selectedUserIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 4),
                    child: Text(
                      '⚠ Nenhum usuário selecionado. O aviso será enviado para TODOS os ${_getRoleLabel(_selectedTargetRole)}s.',
                      style: TextStyle(color: Colors.orange[800], fontSize: 11),
                    ),
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
                      : const Text('SALVAR E NOTIFICAR',
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

  String _getRoleLabel(String role) {
    switch (role) {
      case 'student':
        return 'Aluno';
      case 'nutritionist':
        return 'Nutricionista';
      case 'trainer':
        return 'Personal';
      default:
        return 'Usuário';
    }
  }
}
