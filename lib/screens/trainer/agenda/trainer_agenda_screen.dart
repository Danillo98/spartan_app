import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/trainer_schedule_service.dart';
import '../../../config/app_theme.dart';
import 'create_session_screen.dart';
import 'session_detail_screen.dart';
import 'edit_session_screen.dart';

class TrainerAgendaScreen extends StatefulWidget {
  const TrainerAgendaScreen({super.key});

  @override
  State<TrainerAgendaScreen> createState() => _TrainerAgendaScreenState();
}

class _TrainerAgendaScreenState extends State<TrainerAgendaScreen> {
  DateTime? _selectedDate;
  bool _isLoading = true;
  List<Map<String, dynamic>> _sessions = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final data =
          await TrainerScheduleService.getSessions(filterDate: _selectedDate);
      if (mounted) {
        setState(() {
          _sessions = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteSession(String id) async {
    try {
      await TrainerScheduleService.deleteSession(id);
      _loadSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _confirmDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Treino?'),
        content: const Text('Isso removerá o agendamento.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      _deleteSession(id);
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    // Filter and Sort Logic
    // 1. Filter by Search Query
    final filtered = _sessions.where((s) {
      final name = (s['users_alunos']?['nome'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    // 2. Sort by Date (Closest/Ascending)
    filtered.sort((a, b) {
      final dateA = DateTime.parse(a['scheduled_at']);
      final dateB = DateTime.parse(b['scheduled_at']);
      return dateA.compareTo(dateB);
    });

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text(
          'Minha Agenda',
          style: GoogleFonts.cinzel(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.bold,
          ),
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
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded,
                  color: AppTheme.primaryRed),
              onPressed: () {
                setState(() => _selectedDate = null);
                _loadSessions();
              },
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded,
                color: AppTheme.secondaryText),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.light().copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppTheme.primaryRed,
                        onPrimary: Colors.white,
                        onSurface: AppTheme.primaryText,
                      ),
                      dialogBackgroundColor: Colors.white,
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() => _selectedDate = date);
                _loadSessions();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Status Bar
          if (_selectedDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: AppTheme.primaryRed.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.filter_list,
                      size: 16, color: AppTheme.primaryRed),
                  const SizedBox(width: 8),
                  Text(
                    'Filtrando por: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                    style: TextStyle(
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar aluno...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primaryRed))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy_rounded,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Nenhum aluno encontrado'
                                  : (_selectedDate == null
                                      ? 'Nenhum treino agendado'
                                      : 'Agenda livre neste dia'),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final session = filtered[index];
                          final date =
                              DateTime.parse(session['scheduled_at']).toLocal();
                          final studentName = session['users_alunos']
                                  ?['nome'] ??
                              'Aluno Excluído';

                          return Dismissible(
                            key: Key(session['id']),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => Future.value(
                                false), // Disable swipe to delete without confirm here if preferred, or use confirm dialog.
                            // Better handling below in UI actions
                            background: Container(color: Colors.red),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SessionDetailScreen(session: session),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: AppTheme.cardShadow,
                                  border: Border(
                                    left: BorderSide(
                                      color: _isToday(date)
                                          ? AppTheme.primaryRed
                                          : Colors.transparent,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          DateFormat('HH:mm').format(date),
                                          style: GoogleFonts.lato(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.primaryText,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('dd/MM').format(date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                        width: 1,
                                        height: 40,
                                        color: Colors.grey[200]),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            studentName,
                                            style: GoogleFonts.lato(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryText,
                                            ),
                                          ),
                                          if (session['notes'] != null &&
                                              session['notes'].isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4.0),
                                              child: Text(
                                                session['notes'],
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                    fontStyle:
                                                        FontStyle.italic),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Actions
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded,
                                              color: Colors.blueGrey, size: 20),
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    EditSessionScreen(
                                                        session: session),
                                              ),
                                            );
                                            if (result == true) _loadSessions();
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(8),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.red,
                                              size: 20),
                                          onPressed: () =>
                                              _confirmDelete(session['id']),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(8),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CreateSessionScreen()),
          );
          if (result == true) _loadSessions();
        },
        backgroundColor: AppTheme.primaryRed,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('NOVO TREINO',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
