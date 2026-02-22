import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../config/app_theme.dart';
import '../login_screen.dart';
import 'my_students_screen.dart';
import 'nutritionist_profile_screen.dart';
import '../../widgets/bulletin_board_card.dart';
import 'reports/reports_list_screen.dart';
import '../../widgets/responsive_utils.dart';

class NutritionistDashboard extends StatefulWidget {
  const NutritionistDashboard({super.key});

  @override
  State<NutritionistDashboard> createState() => _NutritionistDashboardState();
}

class _NutritionistDashboardState extends State<NutritionistDashboard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _bulletinKey = 0; // Key para forçar rebuild do BulletinBoard
  Timer? _statusMonitorTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _loadUserData();
    _animationController.forward();

    // Verificação periódica de bloqueio
    _startBlockedStatusMonitor();
  }

  @override
  void dispose() {
    _statusMonitorTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startBlockedStatusMonitor() {
    // Check inicial imediato
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthService.checkBlockedStatus(context);
    });

    // Check periódico a cada 30 segundos
    _statusMonitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      AuthService.checkBlockedStatus(context);
    });
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final data = await AuthService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Carregar dados silenciosamente (sem loading visual)
  Future<void> _silentLoadUserData() async {
    try {
      final data = await AuthService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userData = data;
          _bulletinKey++;
        });
      }
    } catch (e) {
      print('Erro ao carregar dados silenciosamente: $e');
    }
  }

  /// Método universal para refresh do dashboard
  Future<void> _refreshDashboard() async {
    print('🔄 Refreshing Dashboard...');
    if (mounted) {
      await AuthService.checkBlockedStatus(context);
    }
    await _silentLoadUserData();
    print('✅ Dashboard refreshed');
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        title: Text('Sair', style: TextStyle(color: AppTheme.primaryText)),
        content: Text('Deseja realmente sair?',
            style: TextStyle(color: AppTheme.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        FadePageRoute(page: const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _logout();
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Nutricionista',
            style: GoogleFonts.cinzel(
              color: AppTheme.primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          iconTheme: const IconThemeData(color: AppTheme.secondaryText),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Sair',
              color: AppTheme.secondaryText,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: AppTheme.borderGrey,
              height: 1.0,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2A9D8F),
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    child: ResponsiveContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card de boas-vindas modernizado
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF2A9D8F),
                                  const Color(0xFF21867A),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF2A9D8F).withOpacity(0.25),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  key: ValueKey(
                                      _userData?['photo_url'] ?? 'no-photo'),
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    image: _userData?['photo_url'] != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                _userData!['photo_url']),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _userData?['photo_url'] == null
                                      ? const Icon(
                                          Icons.restaurant_menu_rounded,
                                          size: 36,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Olá, Nutri!',
                                        style: GoogleFonts.lato(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Vamos criar planos incríveis hoje?',
                                        style: GoogleFonts.lato(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.95),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Título da seção
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'Ferramentas',
                              style: GoogleFonts.lato(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryText,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Grid de funcionalidades modernizado
                          ResponsiveGrid(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildModernFeatureCard(
                                title: 'Alunos',
                                icon: Icons.people_rounded,
                                color: const Color(0xFF2A9D8F),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MyStudentsNutritionistScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Dietas',
                                icon: Icons.restaurant_menu_rounded,
                                color: const Color(0xFF2A9D8F),
                                onTap: () async {
                                  await Navigator.pushNamed(context, '/diets');
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Avaliações Físicas',
                                icon: Icons.analytics_rounded,
                                color: const Color(0xFF2A9D8F),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ReportsListScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Meu Perfil',
                                icon: Icons.person_rounded,
                                color: const Color(0xFF2A9D8F),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const NutritionistProfileScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Card de avisos modernizado
                          BulletinBoardCard(
                            key: ValueKey(_bulletinKey),
                            baseColor: const Color(0xFF2A9D8F),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildModernFeatureCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Classe auxiliar para transição suave
class FadePageRoute extends PageRouteBuilder {
  final Widget page;
  FadePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
}
