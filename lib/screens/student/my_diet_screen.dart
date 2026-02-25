import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/print_service.dart';
import '../../services/diet_service.dart';
import '../../services/auth_service.dart';
import '../../config/app_theme.dart';

class MyDietScreen extends StatefulWidget {
  const MyDietScreen({super.key});

  @override
  State<MyDietScreen> createState() => _MyDietScreenState();
}

class _MyDietScreenState extends State<MyDietScreen> {
  List<Map<String, dynamic>> _diets = [];
  bool _isLoading = true;
  String? _studentId;

  static const studentPrimary = Color(0xFF2A9D8F);

  @override
  void initState() {
    super.initState();
    _loadDiets();
  }

  Future<void> _loadDiets() async {
    if (_diets.isEmpty) setState(() => _isLoading = true);
    try {
      // Obter ID do aluno logado
      final userData = await AuthService.getCurrentUserData();
      _studentId = userData?['id'];

      if (_studentId != null) {
        final diets = await DietService.getDietsByStudent(_studentId!);
        if (mounted) {
          setState(() {
            _diets = diets;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dietas: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

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
        appBar: AppBar(
          backgroundColor: studentPrimary,
          title: Text(
            'Minhas Dietas',
            style: GoogleFonts.lato(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: studentPrimary),
              )
            : _diets.isEmpty
                ? _buildEmptyState()
                : _buildDietsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: studentPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                size: 64,
                color: studentPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma dieta cadastrada',
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Seu nutricionista ainda não criou uma dieta para você.',
              style: GoogleFonts.lato(
                fontSize: 14,
                color: AppTheme.secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _diets.length,
      itemBuilder: (context, index) {
        final diet = _diets[index];
        return _buildDietCard(diet);
      },
    );
  }

  Widget _buildDietCard(Map<String, dynamic> diet) {
    final status = diet['status'] ?? 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DietDetailsStudentScreen(
                dietId: diet['id'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      diet['name_diet'] ?? 'Sem nome',
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              if (diet['description'] != null &&
                  diet['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  diet['description'],
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.local_fire_department_rounded,
                    '${diet['total_calories'] ?? 0} kcal',
                    const Color(0xFFFF6B6B),
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.flag_rounded,
                    diet['objective_diet'] ?? 'Sem objetivo',
                    studentPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppTheme.secondaryText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Nutricionista: ${diet['nutritionist']?['name'] ?? 'Não informado'}',
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'active':
        color = const Color(0xFF4CAF50);
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
        color = AppTheme.secondaryText;
        label = 'Indefinido';
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
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

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Não definido';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

// Tela de detalhes da dieta para o aluno
class DietDetailsStudentScreen extends StatefulWidget {
  final String dietId;

  const DietDetailsStudentScreen({
    super.key,
    required this.dietId,
  });

  @override
  State<DietDetailsStudentScreen> createState() =>
      _DietDetailsStudentScreenState();
}

class _DietDetailsStudentScreenState extends State<DietDetailsStudentScreen> {
  Map<String, dynamic>? _diet;
  bool _isLoading = true;
  bool _isPrinting = false;

  static const studentPrimary = Color(0xFF2A9D8F);

  @override
  void initState() {
    super.initState();
    _loadDiet();
  }

  Future<void> _loadDiet() async {
    if (_diet == null) setState(() => _isLoading = true);
    try {
      final diet = await DietService.getDietById(widget.dietId);
      print('DEBUG: Diet data: $diet'); // Debug
      if (diet != null) {
        print('DEBUG: diet_days: ${diet['diet_days']}'); // Debug
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

  Future<void> _openPrintPage() async {
    if (_diet == null) return;
    setState(() => _isPrinting = true);

    try {
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

      await PrintService.printReport(
        data: printData,
        templateName: 'print-diet-v2.html',
        localStorageKey: 'spartan_diet_print',
      );

      if (mounted) setState(() => _isPrinting = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

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
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppTheme.lightGrey,
            body: _isLoading ? _buildLoading() : _buildBody(),
          ),
          if (_isPrinting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: studentPrimary),
                        SizedBox(height: 16),
                        Text('Gerando PDF...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: studentPrimary),
    );
  }

  Widget _buildBody() {
    if (_diet == null) {
      return const Center(child: Text('Dieta não encontrada'));
    }

    final days = (_diet!['diet_days'] as List?) ?? [];
    final sortedDays = DietService.sortDaysByWeekOrder(days);

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        SliverToBoxAdapter(child: _buildDietInfo()),
        if (sortedDays.isEmpty)
          SliverFillRemaining(child: _buildEmptyDays())
        else
          SliverToBoxAdapter(child: _buildDaysSection(sortedDays)),
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
              colors: [studentPrimary, Color(0xFF1E7A6F)],
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
                  _buildStatusBadge(status),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Nutri: ${_diet!['nutritionist']?['name'] ?? 'Não informado'}',
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
        IconButton(
          icon: const Icon(Icons.print_rounded, color: Colors.white),
          onPressed: _openPrintPage,
          tooltip: 'Imprimir Dieta',
        ),
        const SizedBox(width: 8),
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
                  studentPrimary,
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.calendar_view_week_rounded,
                    color: studentPrimary),
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
              ],
            ),
          ),
          const Divider(height: 1),
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

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: studentPrimary.withOpacity(0.1),
        child: Text(
          '${day['day_number'] ?? '?'}',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: studentPrimary,
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
        '${meals.length} ${meals.length == 1 ? 'refeição' : 'refeições'}', // Removido calorias daqui, vai pro rodapé
        style: GoogleFonts.lato(
          fontSize: 13,
          color: AppTheme.secondaryText,
        ),
      ),
      children: [
        if (meals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildDayTotals(day),
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
          ...meals.map<Widget>((meal) => _buildMealItem(meal)).toList(),
      ],
    );
  }

  Widget _buildDayTotals(Map<String, dynamic> day) {
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
              color: studentPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTotalItem(
                    'Cal', '$totalCalories', const Color(0xFFFF6B6B)),
                _buildTotalItem(
                    'P', '${totalProtein}g', const Color(0xFF4CAF50)),
                _buildTotalItem('C', '${totalCarbs}g', const Color(0xFF2196F3)),
                _buildTotalItem('G', '${totalFats}g', const Color(0xFFFFA726)),
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

  Widget _buildMealItem(Map<String, dynamic> meal) {
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
                  color: studentPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: studentPrimary,
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
              Text(
                '${meal['calories'] ?? 0} kcal',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF6B6B),
                ),
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
          if (meal['instructions'] != null &&
              meal['instructions'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Instruções:',
              style: GoogleFonts.lato(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meal['instructions'],
              style: GoogleFonts.lato(
                fontSize: 14,
                color: AppTheme.primaryText,
                height: 1.4,
              ),
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
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
              Icons.calendar_today_rounded,
              size: 64,
              color: AppTheme.secondaryText.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum dia cadastrado',
              style: GoogleFonts.lato(
                fontSize: 16,
                color: AppTheme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Não definido';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
