import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/diet_service.dart';
import '../../config/app_theme.dart';
import 'create_diet_screen.dart';
import 'diet_details_screen.dart';
import '../../widgets/diet_card.dart';

class DietsListScreen extends StatefulWidget {
  const DietsListScreen({super.key});

  @override
  State<DietsListScreen> createState() => _DietsListScreenState();
}

class _DietsListScreenState extends State<DietsListScreen> {
  List<Map<String, dynamic>> _diets = [];
  List<Map<String, dynamic>> _filteredDiets = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, active, paused, completed

  // Cor do Nutricionista
  static const nutritionistPrimary = Color(0xFF2A9D8F);
  static const nutritionistLight = Color(0xFFE8F5F3);

  @override
  void initState() {
    super.initState();
    _loadDiets();
  }

  Future<void> _loadDiets() async {
    setState(() => _isLoading = true);
    try {
      final diets = await DietService.getAllDiets();
      setState(() {
        _diets = diets;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dietas: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredDiets = _diets.where((diet) {
        // Filtro de busca
        final matchesSearch = _searchQuery.isEmpty ||
            (diet['name_diet'] != null &&
                diet['name_diet']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase())) ||
            (diet['student'] != null &&
                diet['student']['name']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()));

        // Filtro de status
        final matchesStatus =
            _statusFilter == 'all' || diet['status'] == _statusFilter;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  int get _activeDietsCount =>
      _diets.where((d) => d['status'] == 'active').length;
  int get _pausedDietsCount =>
      _diets.where((d) => d['status'] == 'paused').length;
  int get _completedDietsCount =>
      _diets.where((d) => d['status'] == 'completed').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoading() : _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [nutritionistPrimary, Color(0xFF4CAF50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Text(
        'Minhas Dietas',
        style: GoogleFonts.lato(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: nutritionistPrimary,
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadDiets,
      color: nutritionistPrimary,
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

          // Lista de dietas
          _filteredDiets.isEmpty
              ? SliverFillRemaining(
                  child: _buildEmptyState(),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final diet = _filteredDiets[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DietCard(
                            diet: diet,
                            onTap: () => _navigateToDietDetails(diet),
                            onDelete: () => _confirmDelete(diet),
                          ),
                        );
                      },
                      childCount: _filteredDiets.length,
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
            color: nutritionistPrimary.withOpacity(0.1),
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
                  _diets.length.toString(),
                  Icons.restaurant_menu_rounded,
                  nutritionistPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Ativas',
                  _activeDietsCount.toString(),
                  Icons.check_circle_rounded,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pausadas',
                  _pausedDietsCount.toString(),
                  Icons.pause_circle_rounded,
                  const Color(0xFFFFA726),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Concluídas',
                  _completedDietsCount.toString(),
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
                hintText: 'Buscar por nome da dieta ou aluno...',
                hintStyle: GoogleFonts.lato(color: AppTheme.secondaryText),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: nutritionistPrimary),
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
                _buildFilterChip('Todas', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Ativas', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Pausadas', 'paused'),
                const SizedBox(width: 8),
                _buildFilterChip('Concluídas', 'completed'),
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
      selectedColor: nutritionistPrimary.withOpacity(0.2),
      checkmarkColor: nutritionistPrimary,
      labelStyle: GoogleFonts.lato(
        color: isSelected ? nutritionistPrimary : AppTheme.secondaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? nutritionistPrimary : AppTheme.borderGrey,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: 80,
            color: AppTheme.secondaryText.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty && _statusFilter == 'all'
                ? 'Nenhuma dieta criada ainda'
                : 'Nenhuma dieta encontrada',
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty && _statusFilter == 'all'
                ? 'Crie sua primeira dieta clicando no botão abaixo'
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
      onPressed: _navigateToCreateDiet,
      backgroundColor: nutritionistPrimary,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'Nova Dieta',
        style: GoogleFonts.lato(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _navigateToCreateDiet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateDietScreen(),
      ),
    );

    if (result == true) {
      _loadDiets();
    }
  }

  void _navigateToDietDetails(Map<String, dynamic> diet) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DietDetailsScreen(dietId: diet['id']),
      ),
    );

    if (result == true) {
      _loadDiets();
    }
  }

  void _confirmDelete(Map<String, dynamic> diet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Excluir Dieta',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tem certeza que deseja excluir a dieta "${diet['name_diet'] ?? 'Sem nome'}"?\n\nEsta ação não pode ser desfeita.',
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
              await _deleteDiet(diet['id']);
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

  Future<void> _deleteDiet(String dietId) async {
    try {
      final result = await DietService.deleteDiet(dietId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor:
                result['success'] ? nutritionistPrimary : AppTheme.accentRed,
          ),
        );
        if (result['success']) {
          _loadDiets();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir dieta: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }
}
