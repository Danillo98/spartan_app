import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/workout_service.dart';
import '../../config/app_theme.dart';
import 'create_workout_screen.dart';
import 'workout_details_screen.dart';
import '../../widgets/workout_card.dart';

class WorkoutsListScreen extends StatefulWidget {
  const WorkoutsListScreen({super.key});

  @override
  State<WorkoutsListScreen> createState() => _WorkoutsListScreenState();
}

class _WorkoutsListScreenState extends State<WorkoutsListScreen> {
  List<Map<String, dynamic>> _workouts = [];
  List<Map<String, dynamic>> _filteredWorkouts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, active, completed

  // Cor do Personal (Vermelho)
  static const trainerPrimary = AppTheme.primaryRed;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    if (_workouts.isEmpty) setState(() => _isLoading = true);
    try {
      final workouts = await WorkoutService.getWorkouts();
      setState(() {
        _workouts = workouts;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar treinos: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredWorkouts = _workouts.where((workout) {
        // Mapear is_active para status
        final bool isActive = workout['is_active'] ?? true;
        final String status = isActive ? 'active' : 'completed';

        // Filtro de busca
        final matchesSearch = _searchQuery.isEmpty ||
            (workout['name'] != null &&
                workout['name']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase())) ||
            (workout['student'] != null &&
                workout['student']['name']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()));

        // Filtro de status
        final matchesStatus = _statusFilter == 'all' || status == _statusFilter;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  int get _activeWorkoutsCount =>
      _workouts.where((w) => w['is_active'] == true).length;

  int get _completedWorkoutsCount =>
      _workouts.where((w) => w['is_active'] == false).length;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: _buildAppBar(),
        body: _isLoading ? _buildLoading() : _buildBody(),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [trainerPrimary, Color(0xFFB71C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Text(
        'Fichas de Treino',
        style: GoogleFonts.lato(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: trainerPrimary,
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadWorkouts,
      color: trainerPrimary,
      child: CustomScrollView(
        slivers: [
          // Estatísticas
          SliverToBoxAdapter(
            child: _buildStatistics(),
          ),

          // Barra de busca e filtros
          SliverToBoxAdapter(
            child: _buildSearchAndFilters(),
          ),

          // Lista de treinos
          _filteredWorkouts.isEmpty
              ? SliverFillRemaining(
                  child: _buildEmptyState(),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final workout = _filteredWorkouts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: WorkoutCard(
                            workout: workout,
                            onTap: () => _navigateToWorkoutDetails(workout),
                            onDelete: () => _confirmDelete(workout),
                            onStatusToggle: () =>
                                _showStatusChangeSheet(workout),
                          ),
                        );
                      },
                      childCount: _filteredWorkouts.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: trainerPrimary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo',
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  _workouts.length.toString(),
                  Icons.fitness_center_rounded,
                  trainerPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Ativos',
                  _activeWorkoutsCount.toString(),
                  Icons.check_circle_rounded,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Concluídos',
                  _completedWorkoutsCount.toString(),
                  Icons.done_all_rounded,
                  const Color(0xFF757575),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 11,
              color: AppTheme.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Barra de busca
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou aluno...',
                hintStyle: GoogleFonts.lato(color: AppTheme.secondaryText),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: trainerPrimary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filtros de status
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Todos', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Ativos', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Concluídos', 'completed'),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _statusFilter = value);
        _applyFilters();
      },
      backgroundColor: Colors.white,
      selectedColor: trainerPrimary.withOpacity(0.2),
      checkmarkColor: trainerPrimary,
      labelStyle: GoogleFonts.lato(
        color: isSelected ? trainerPrimary : AppTheme.secondaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? trainerPrimary : AppTheme.borderGrey,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 80,
            color: AppTheme.secondaryText.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty && _statusFilter == 'all'
                ? 'Nenhuma ficha de treino criada'
                : 'Nenhum treino encontrado',
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty && _statusFilter == 'all'
                ? 'Crie sua primeira ficha clicando no botão abaixo'
                : 'Tente ajustar os filtros de busca',
            style: GoogleFonts.lato(
              fontSize: 14,
              color: AppTheme.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      heroTag: 'fab_nova_ficha',
      onPressed: _navigateToCreateWorkout,
      backgroundColor: trainerPrimary,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'Nova Ficha',
        style: GoogleFonts.lato(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _navigateToCreateWorkout() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateWorkoutScreen(),
      ),
    );
    _loadWorkouts();
  }

  void _navigateToWorkoutDetails(Map<String, dynamic> workout) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutDetailsScreen(
          workoutId: workout['id'],
          workoutName: workout['name'] ?? 'Detalhes do Treino',
        ),
      ),
    );
    _loadWorkouts();
  }

  void _confirmDelete(Map<String, dynamic> workout) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Excluir Ficha',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tem certeza que deseja excluir a ficha "${workout['name'] ?? 'Sem nome'}"?\n\nEsta ação não pode ser desfeita.',
          style: GoogleFonts.lato(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.lato(color: AppTheme.secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteWorkout(workout['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
            ),
            child: Text(
              'Excluir',
              style: GoogleFonts.lato(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWorkout(String workoutId) async {
    try {
      final result = await WorkoutService.deleteWorkout(workoutId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor:
                result['success'] ? trainerPrimary : AppTheme.accentRed,
          ),
        );
        if (result['success']) {
          _loadWorkouts();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir ficha: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  void _showStatusChangeSheet(Map<String, dynamic> workout) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alterar Status da Ficha',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              const SizedBox(height: 24),
              _buildStatusOption(
                icon: Icons.check_circle_rounded,
                label: 'Ativa',
                description: 'A ficha está em uso',
                color: const Color(0xFF4CAF50),
                isSelected: workout['is_active'] == true,
                onTap: () {
                  Navigator.pop(context);
                  _updateWorkoutStatus(workout, true);
                },
              ),
              const SizedBox(height: 12),
              _buildStatusOption(
                icon: Icons.done_all_rounded,
                label: 'Concluída',
                description: 'A ficha foi finalizada',
                color: const Color(0xFF757575),
                isSelected: workout['is_active'] == false,
                onTap: () {
                  Navigator.pop(context);
                  _updateWorkoutStatus(workout, false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusOption({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderGrey,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _updateWorkoutStatus(
      Map<String, dynamic> workout, bool newStatus) async {
    final isActive = workout['is_active'] ?? true;
    if (isActive == newStatus) return;

    // Optimistic update
    final index = _workouts.indexWhere((w) => w['id'] == workout['id']);
    if (index != -1) {
      setState(() {
        _workouts[index]['is_active'] = newStatus;
        _applyFilters();
      });
    }

    try {
      final result = await WorkoutService.updateWorkout(
        workoutId: workout['id'],
        isActive: newStatus,
      );

      if (!result['success']) {
        throw Exception(result['message']);
      }
    } catch (e) {
      // Revert
      if (index != -1) {
        setState(() {
          _workouts[index]['is_active'] = isActive;
          _applyFilters();
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar status: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }
}
