import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/diet_service.dart';
import '../../config/app_theme.dart';
import 'add_diet_day_with_meals_screen.dart'; // Tela de adicionar refeições
import 'add_single_meal_screen.dart'; // Tela de adicionar refeição individual
import 'edit_meal_screen.dart'; // Tela de editar refeição
import 'edit_diet_screen.dart';

class DietDetailsScreen extends StatefulWidget {
  final String dietId;

  const DietDetailsScreen({
    super.key,
    required this.dietId,
  });

  @override
  State<DietDetailsScreen> createState() => _DietDetailsScreenState();
}

class _DietDetailsScreenState extends State<DietDetailsScreen> {
  Map<String, dynamic>? _diet;
  bool _isLoading = true;

  static const nutritionistPrimary = Color(0xFF2A9D8F);

  @override
  void initState() {
    super.initState();
    _loadDiet();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadDiet() async {
    setState(() => _isLoading = true);
    try {
      final diet = await DietService.getDietById(widget.dietId);
      if (diet != null) {
        setState(() {
          _diet = diet;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dieta não encontrada'),
              backgroundColor: AppTheme.accentRed,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dieta: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      body: _isLoading ? _buildLoading() : _buildBody(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: nutritionistPrimary),
    );
  }

  Widget _buildBody() {
    if (_diet == null) {
      return const Center(child: Text('Dieta não encontrada'));
    }

    final days = (_diet!['diet_days'] as List?) ?? [];
    // Ordenar dias da semana
    final sortedDays = DietService.sortDaysByWeekOrder(days);

    return CustomScrollView(
      slivers: [
        // AppBar com informações principais
        _buildSliverAppBar(),

        // Informações da dieta
        SliverToBoxAdapter(
          child: _buildDietInfo(),
        ),

        // Dias e refeições
        if (sortedDays.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyDays(),
          )
        else
          SliverToBoxAdapter(
            child: _buildDaysSection(sortedDays),
          ),
      ],
    );
  }

  Widget _buildSliverAppBar() {
    final status = _diet!['status'] ?? 'active';

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [nutritionistPrimary, Color(0xFF4CAF50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _diet!['name_diet'] ?? 'Sem nome',
                    style: GoogleFonts.lato(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusBadge(status),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _diet!['student']?['name'] ?? 'Aluno não atribuído',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        PopupMenuButton(
          icon: const Icon(Icons.more_vert_rounded),
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text('Editar', style: GoogleFonts.lato()),
                ],
              ),
              onTap: () async {
                // Aguardar um frame para fechar o menu antes de navegar
                await Future.delayed(const Duration(milliseconds: 100));
                if (mounted) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditDietScreen(diet: _diet!),
                    ),
                  );
                  if (result == true) {
                    _loadDiet(); // Recarregar dieta após edição
                  }
                }
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text('Baixar PDF', style: GoogleFonts.lato()),
                ],
              ),
              onTap: () async {
                await Future.delayed(const Duration(milliseconds: 100));
                if (mounted) {
                  _openPrintPage();
                }
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    _diet!['status'] == 'active'
                        ? Icons.pause_circle_rounded
                        : Icons.play_circle_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _diet!['status'] == 'active' ? 'Pausar' : 'Ativar',
                    style: GoogleFonts.lato(),
                  ),
                ],
              ),
              onTap: () => _toggleStatus(),
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text('Concluído', style: GoogleFonts.lato()),
                ],
              ),
              onTap: () => _markAsCompleted(),
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.delete_rounded,
                      size: 20, color: AppTheme.accentRed),
                  const SizedBox(width: 12),
                  Text(
                    'Excluir',
                    style: GoogleFonts.lato(color: AppTheme.accentRed),
                  ),
                ],
              ),
              onTap: () => _confirmDelete(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'active':
        color = Colors.white;
        label = 'Ativa';
        icon = Icons.check_circle_rounded;
        break;
      case 'paused':
        color = const Color(0xFFFFA726);
        label = 'Pausada';
        icon = Icons.pause_circle_rounded;
        break;
      case 'completed':
        color = const Color(0xFF757575);
        label = 'Concluída';
        icon = Icons.done_all_rounded;
        break;
      default:
        color = Colors.white;
        label = 'Indefinido';
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status == 'active'
            ? Colors.white.withOpacity(0.2)
            : color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_diet!['description'] != null &&
              _diet!['description'].toString().isNotEmpty) ...[
            Text(
              'Descrição',
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _diet!['description'],
              style: GoogleFonts.lato(
                fontSize: 15,
                color: AppTheme.primaryText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Informações em grid
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  Icons.local_fire_department_rounded,
                  'Calorias',
                  '${_diet!['total_calories'] ?? 0} kcal',
                  const Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoItem(
                  Icons.flag_rounded,
                  'Objetivo',
                  _diet!['objective_diet'] ?? 'Não especificado',
                  nutritionistPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  Icons.calendar_today_rounded,
                  'Início',
                  _formatDate(_diet!['start_date']),
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoItem(
                  Icons.event_rounded,
                  'Término',
                  _diet!['end_date'] != null
                      ? _formatDate(_diet!['end_date'])
                      : 'Não definido',
                  const Color(0xFF757575),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSection(List days) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.calendar_view_week_rounded,
                    color: nutritionistPrimary),
                const SizedBox(width: 12),
                Text(
                  'Dias e Refeições',
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
                const Spacer(),
                Text(
                  '${days.length} ${days.length == 1 ? 'dia' : 'dias'}',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddDietDayWithMealsScreen(dietId: widget.dietId),
                      ),
                    );
                    if (result == true) {
                      _loadDiet();
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    'Adicionar',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: nutritionistPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Lista de dias
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final day = days[index];
              return _buildDayItem(day);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayItem(Map<String, dynamic> day) {
    final meals = (day['meals'] as List?) ?? [];

    // Calcular totais do dia
    int totalCalories = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFats = 0;

    for (var meal in meals) {
      totalCalories += (meal['calories'] as int?) ?? 0;
      totalProtein += (meal['protein'] as int?) ?? 0;
      totalCarbs += (meal['carbs'] as int?) ?? 0;
      totalFats += (meal['fats'] as int?) ?? 0;
    }

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: nutritionistPrimary.withOpacity(0.1),
        child: Text(
          '${day['day_number'] ?? '?'}',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: nutritionistPrimary,
          ),
        ),
      ),
      title: Text(
        day['day_name'] ?? 'Dia sem nome',
        style: GoogleFonts.lato(
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryText,
        ),
      ),
      subtitle: Text(
        '${meals.length} ${meals.length == 1 ? 'refeição' : 'refeições'}',
        style: GoogleFonts.lato(
          fontSize: 13,
          color: AppTheme.secondaryText,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.accentRed),
            onPressed: () => _confirmDeleteDay(day['id'], day['day_name']),
            tooltip: 'Excluir dia',
          ),
          const Icon(Icons.expand_more_rounded),
        ],
      ),
      children: [
        if (meals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildDayTotals(
                totalCalories, totalProtein, totalCarbs, totalFats),
          ),
        if (meals.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.restaurant_rounded,
                  size: 48,
                  color: AppTheme.secondaryText.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nenhuma refeição cadastrada',
                  style: GoogleFonts.lato(
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          )
        else
          ...meals
              .map<Widget>(
                  (meal) => _buildMealItem(meal, day['day_name'] ?? 'Dia'))
              .toList(), // Passando dayName

        // Botão Adicionar Refeição ao final
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddSingleMealScreen(
                    dietDayId: day['id'],
                    dayName: day['day_name'] ?? 'Dia',
                  ),
                ),
              );
              if (result == true) {
                _loadDiet(); // Recarregar dieta
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar Refeição'),
            style: TextButton.styleFrom(
              foregroundColor: nutritionistPrimary,
              backgroundColor: nutritionistPrimary.withOpacity(0.1),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayTotals(int cal, int prot, int carb, int fat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'TOTAL:',
            style: GoogleFonts.lato(
              fontWeight: FontWeight.bold,
              color: nutritionistPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTotalItem('Cal', '$cal', const Color(0xFFFF6B6B)),
                _buildTotalItem('P', '${prot}g', const Color(0xFF4CAF50)),
                _buildTotalItem('C', '${carb}g', const Color(0xFF2196F3)),
                _buildTotalItem('G', '${fat}g', const Color(0xFFFFA726)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.lato(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildMealItem(Map<String, dynamic> meal, String dayName) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: nutritionistPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: nutritionistPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          if (meal['meal_time'] != null &&
                              meal['meal_time'].toString().isNotEmpty) ...[
                            TextSpan(
                              text: '${meal['meal_time']} - ',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                          ],
                          TextSpan(
                            text: meal['meal_name'] ?? 'Sem nome',
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${meal['calories'] ?? 0} kcal',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF6B6B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditMealScreen(
                                meal: meal,
                                dayName: dayName,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadDiet(); // Recarregar dieta após editar
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: nutritionistPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () =>
                            _confirmDeleteMeal(meal['id'], meal['meal_name']),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppTheme.accentRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          if (meal['foods'] != null && meal['foods'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Alimentos:',
              style: GoogleFonts.lato(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meal['foods'],
              style: GoogleFonts.lato(
                fontSize: 14,
                color: AppTheme.primaryText,
                height: 1.4,
              ),
            ),
          ],

          // Macros
          if (meal['protein'] != null ||
              meal['carbs'] != null ||
              meal['fats'] != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (meal['protein'] != null)
                  _buildMacroChip(
                      'P', '${meal['protein']}g', const Color(0xFF4CAF50)),
                if (meal['carbs'] != null) ...[
                  const SizedBox(width: 8),
                  _buildMacroChip(
                      'C', '${meal['carbs']}g', const Color(0xFF2196F3)),
                ],
                if (meal['fats'] != null) ...[
                  const SizedBox(width: 8),
                  _buildMacroChip(
                      'G', '${meal['fats']}g', const Color(0xFFFFA726)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDays() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_view_week_rounded,
              size: 80,
              color: AppTheme.secondaryText.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum dia cadastrado',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione dias e refeições para completar a dieta',
              style: GoogleFonts.lato(
                fontSize: 14,
                color: AppTheme.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddDietDayWithMealsScreen(dietId: widget.dietId),
                  ),
                );
                if (result == true) {
                  _loadDiet(); // Recarregar dieta após adicionar dia
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar Dia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: nutritionistPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Não definido';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Data inválida';
    }
  }

  void _openPrintPage() async {
    try {
      // Preparar dados para impressão
      final printData = {
        'name_diet': _diet!['name_diet'],
        'description': _diet!['description'],
        'student_name': _diet!['student']?['name'],
        'nutritionist_name': _diet!['nutritionist']?['name'],
        'objective_diet': _diet!['objective_diet'],
        'total_calories': _diet!['total_calories'],
        'start_date': _diet!['start_date'],
        'end_date': _diet!['end_date'],
        'diet_days': _diet!['diet_days'],
      };

      // Converter para JSON
      final jsonData = jsonEncode(printData);

      // Salvar no localStorage (evita limite de URL)
      // ignore: avoid_web_libraries_in_flutter
      html.window.localStorage['spartan_diet_print'] = jsonData;

      // Construir URL (v2 + timestamp para evitar cache)
      final baseUrl = Uri.base.origin;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final printUrl = '$baseUrl/print-diet-v2.html?v=$timestamp';

      // Abrir em nova aba
      html.window.open(printUrl, '_blank');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Abrindo página de impressão...',
              style: GoogleFonts.lato(),
            ),
            backgroundColor: nutritionistPrimary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Erro ao abrir página de impressão: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao gerar PDF: $e',
              style: GoogleFonts.lato(),
            ),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  void _toggleStatus() async {
    final currentStatus = _diet!['status'];
    final newStatus = currentStatus == 'active' ? 'paused' : 'active';

    final result = await DietService.updateDiet(
      dietId: widget.dietId,
      status: newStatus,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor:
              result['success'] ? nutritionistPrimary : AppTheme.accentRed,
        ),
      );

      if (result['success']) {
        _loadDiet();
      }
    }
  }

  void _markAsCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Concluir Dieta',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Deseja marcar esta dieta como concluída?',
          style: GoogleFonts.lato(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.lato(color: AppTheme.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: nutritionistPrimary,
            ),
            child: Text('Concluir', style: GoogleFonts.lato()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await DietService.updateDiet(
        dietId: widget.dietId,
        status: 'completed',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor:
                result['success'] ? nutritionistPrimary : AppTheme.accentRed,
          ),
        );

        if (result['success']) {
          _loadDiet();
        }
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Excluir Dieta',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tem certeza que deseja excluir esta dieta?\n\nEsta ação não pode ser desfeita.',
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
              await _deleteDiet();
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

  Future<void> _deleteDiet() async {
    final result = await DietService.deleteDiet(widget.dietId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor:
              result['success'] ? nutritionistPrimary : AppTheme.accentRed,
        ),
      );

      if (result['success']) {
        Navigator.pop(context, true);
      }
    }
  }

  void _confirmDeleteDay(String dayId, String? dayName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Excluir Dia',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tem certeza que deseja excluir "${dayName ?? 'este dia'}"?\n\nTodas as refeições deste dia também serão excluídas.\n\nEsta ação não pode ser desfeita.',
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
              await _deleteDay(dayId);
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

  Future<void> _deleteDay(String dayId) async {
    final result = await DietService.deleteDietDay(dayId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor:
              result['success'] ? nutritionistPrimary : AppTheme.accentRed,
        ),
      );

      if (result['success']) {
        _loadDiet(); // Recarregar dieta
      }
    }
  }

  void _confirmDeleteMeal(String mealId, String? mealName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Excluir Refeição',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tem certeza que deseja excluir "${mealName ?? 'esta refeição'}"?\n\nEsta ação não pode ser desfeita.',
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
              await _deleteMeal(mealId);
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

  Future<void> _deleteMeal(String mealId) async {
    final result = await DietService.deleteMeal(mealId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor:
              result['success'] ? nutritionistPrimary : AppTheme.accentRed,
        ),
      );

      if (result['success']) {
        _loadDiet(); // Recarregar dieta
      }
    }
  }
}
