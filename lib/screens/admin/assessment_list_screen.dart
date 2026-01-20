import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../services/appointment_service.dart';
import 'schedule_assessment_screen.dart';

class AssessmentListScreen extends StatefulWidget {
  const AssessmentListScreen({super.key});

  @override
  State<AssessmentListScreen> createState() => _AssessmentListScreenState();
}

class _AssessmentListScreenState extends State<AssessmentListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  String _currentFilter = 'scheduled'; // 'all', 'scheduled', 'completed'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final filter = _currentFilter == 'all' ? null : _currentFilter;
      final data =
          await AppointmentService.getAppointments(statusFilter: filter);

      if (mounted) {
        setState(() {
          _appointments = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar agenda: $e')),
        );
      }
    }
  }

  // Filtragem local para busca por nome (já que o service filtra por status)
  List<Map<String, dynamic>> get _visibleList {
    if (_searchQuery.isEmpty) return _appointments;

    return _appointments.where((a) {
      final name = (a['display_name'] as String).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text(
          'Avaliações Físicas',
          style: GoogleFonts.cinzel(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.secondaryText),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppTheme.borderGrey, height: 1.0),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ScheduleAssessmentScreen()),
          );
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: AppTheme.primaryText,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Agendar Avaliação',
            style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Header: Pesquisa e Filtros
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.white,
            child: Column(
              children: [
                // Pesquisa
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Pesquisar Aluno...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppTheme.lightGrey,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),
                // Filtros
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                          'Aguardando', 'scheduled', Colors.orange),
                      const SizedBox(width: 8),
                      _buildFilterChip('Concluídas', 'completed', Colors.green),
                      const SizedBox(width: 8),
                      _buildFilterChip('Canceladas', 'cancelled', Colors.red),
                      const SizedBox(width: 8),
                      _buildFilterChip('Todas', 'all', AppTheme.primaryText),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _visibleList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('Nenhuma avaliação encontrada',
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _visibleList.length,
                        itemBuilder: (context, index) {
                          return _buildAppointmentCard(_visibleList[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAppointment(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Avaliação'),
        content: const Text('Tem certeza que deseja remover este agendamento?'),
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

    if (confirmed == true) {
      try {
        await AppointmentService.deleteAppointment(id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Agendamento excluído.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      }
    }
  }

  Future<void> _editAppointment(Map<String, dynamic> appt) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              ScheduleAssessmentScreen(appointmentToEdit: appt)),
    );
    if (result == true) {
      _loadData();
    }
  }

  Widget _buildFilterChip(String label, String value, Color activeColor) {
    final isSelected = _currentFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _currentFilter = value);
          _loadData();
        }
      },
      selectedColor: activeColor,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.grey.shade300),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final dateStr = appointment['scheduled_at'];
    final date = DateTime.parse(dateStr).toLocal();
    final status = appointment['status']; // scheduled, completed, cancelled
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';

    Color statusColor = Colors.orange[800]!;
    Color statusBg = Colors.orange.withOpacity(0.1);

    if (isCompleted) {
      statusColor = Colors.green;
      statusBg = Colors.green.withOpacity(0.1);
    } else if (isCancelled) {
      statusColor = Colors.red;
      statusBg = Colors.red.withOpacity(0.1);
    }

    final name = appointment['display_name'];
    final phone = appointment['display_phone'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Data Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('dd').format(date),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('HH:mm').format(date),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (phone != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Ações: Edit, Delete (Sem Check)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _editAppointment(appointment),
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  color: Colors.grey[600],
                  tooltip: 'Editar',
                ),
                IconButton(
                  onPressed: () => _deleteAppointment(appointment['id']),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: Colors.red[400],
                  tooltip: 'Excluir',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
