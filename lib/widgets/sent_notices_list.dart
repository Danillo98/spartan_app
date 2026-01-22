import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/notice_service.dart';
import '../config/app_theme.dart';

class SentNoticesList extends StatefulWidget {
  final Color baseColor;

  const SentNoticesList({super.key, required this.baseColor});

  @override
  State<SentNoticesList> createState() => _SentNoticesListState();
}

class _SentNoticesListState extends State<SentNoticesList> {
  List<Map<String, dynamic>> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() => _isLoading = true);
    try {
      final data = await NoticeService.getMyNotices();
      if (mounted) {
        setState(() {
          _notices = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
              child:
                  const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await NoticeService.deleteNotice(id);
      _loadNotices();
    }
  }

  // TODO: Implementar Edição se necessário (é um pouco complexo abrir o mesmo dialog, deixaremos para exclusão por enquanto ou edição simples)
  // Por ora, vamos focar em EXCLUIR, já que edição full requer passar controladores preenchidos.

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return Center(child: CircularProgressIndicator(color: widget.baseColor));

    if (_notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Nenhum aviso enviado',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notices.length,
      itemBuilder: (context, index) {
        final notice = _notices[index];
        final studentName = notice['users_alunos']?['nome'] ?? 'Todos (Geral)';
        final start = DateTime.parse(notice['start_at']).toLocal();
        final end = DateTime.parse(notice['end_at']).toLocal();
        final isActive =
            DateTime.now().isAfter(start) && DateTime.now().isBefore(end);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive
                            ? 'IMEDIATO'
                            : (DateTime.now().isBefore(start)
                                ? 'AGENDADO'
                                : 'EXPIRADO'),
                        style: TextStyle(
                          color:
                              isActive ? Colors.green[800] : Colors.grey[800],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.baseColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 12, color: widget.baseColor),
                          const SizedBox(width: 4),
                          Text(studentName,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: widget.baseColor,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notice['title'],
                  style: GoogleFonts.lato(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  notice['description'],
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('dd/MM').format(start)} - ${DateFormat('dd/MM').format(end)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    // Actions
                    IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          size: 20, color: Colors.blue),
                      onPressed: () => _editNotice(notice),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: Colors.red),
                      onPressed: () => _deleteNotice(notice['id']),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _editNotice(Map<String, dynamic> notice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditNoticeDialog(
        notice: notice,
        baseColor: widget.baseColor,
        onSave: _loadNotices,
      ),
    );
  }
}

class _EditNoticeDialog extends StatefulWidget {
  final Map<String, dynamic> notice;
  final Color baseColor;
  final VoidCallback onSave;

  const _EditNoticeDialog({
    required this.notice,
    required this.baseColor,
    required this.onSave,
  });

  @override
  State<_EditNoticeDialog> createState() => _EditNoticeDialogState();
}

class _EditNoticeDialogState extends State<_EditNoticeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late DateTime _startAt;
  late DateTime _endAt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notice['title']);
    _descController = TextEditingController(text: widget.notice['description']);
    _startAt = DateTime.parse(widget.notice['start_at']).toLocal();
    _endAt = DateTime.parse(widget.notice['end_at']).toLocal();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initialDate = isStart ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: widget.baseColor),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(primary: widget.baseColor),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          final newDateTime =
              DateTime(date.year, date.month, date.day, time.hour, time.minute);
          if (isStart) {
            _startAt = newDateTime;
          } else {
            _endAt = newDateTime;
          }
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endAt.isBefore(_startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A data final deve ser após a inicial')));
      return;
    }

    try {
      await NoticeService.updateNotice(
        id: widget.notice['id'],
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        startAt: _startAt,
        endAt: _endAt,
      );
      widget.onSave();
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aviso atualizado com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Aviso',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => v!.isEmpty ? 'Informe o título' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: (v) => v!.isEmpty ? 'Informe a descrição' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDateTime(true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Início', border: OutlineInputBorder()),
                        child: Text(DateFormat('dd/MM HH:mm').format(_startAt)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDateTime(false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Fim', border: OutlineInputBorder()),
                        child: Text(DateFormat('dd/MM HH:mm').format(_endAt)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: widget.baseColor),
          child: const Text('Salvar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
