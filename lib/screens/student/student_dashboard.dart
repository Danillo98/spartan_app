import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/financial_service.dart';
import '../../config/app_theme.dart';
import '../login_screen.dart';
import 'student_profile_screen.dart';
import 'my_diet_screen.dart';
import 'my_workout_screen.dart';
import '../../widgets/bulletin_board_card.dart';
import 'reports/student_reports_list_screen.dart';
import '../../widgets/responsive_utils.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
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

    // Verificação proativa de bloqueio
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
    if (_userData == null) setState(() => _isLoading = true);
    try {
      final data = await AuthService.getCurrentUserData();

      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });

        // Gravar role para persistência de login (UX solicitada)
        if (data != null && data['role'] != null) {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('saved_login_role', data['role']);
          });
        }

        // Verificação de Inadimplência
        if (data != null && data['role'] == 'student') {
          _checkFinancialStatus(data);
        }
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
          _bulletinKey++; // Força atualização do BulletinBoard
        });
        if (data != null && data['role'] == 'student') {
          _checkFinancialStatus(data);
        }
      }
    } catch (e) {
      print('Erro ao carregar dados silenciosamente: $e');
    }
  }

  /// Método universal para refresh do dashboard
  /// Chame este método ao voltar de QUALQUER tela para:
  /// 1. Verificar bloqueio manual do admin
  /// 2. Atualizar quadro de avisos
  /// 3. Atualizar dados do usuário (incluindo foto de perfil)
  Future<void> _refreshDashboard() async {
    print('🔄 Refreshing Dashboard...');

    // 1. Verificar se usuário foi bloqueado
    if (mounted) {
      await AuthService.checkBlockedStatus(context);
    }

    // 2. Recarregar dados (força rebuild de todos widgets, incluindo BulletinBoard)
    await _silentLoadUserData();

    print('✅ Dashboard refreshed');
  }

  Future<void> _checkFinancialStatus(Map<String, dynamic> data) async {
    final studentId = data['id'];
    final idAcademia = data['id_academia'];
    final paymentDueDay = data['payment_due_day'];

    if (idAcademia != null) {
      final gracePeriod = (data['grace_period'] ?? 3) as int;
      bool isOverdue = false;
      try {
        isOverdue = await FinancialService.isStudentOverdue(
          studentId: studentId,
          idAcademia: idAcademia,
          paymentDueDay: paymentDueDay is int
              ? paymentDueDay
              : int.tryParse(paymentDueDay.toString()),
          gracePeriod: gracePeriod,
        );
      } catch (e) {
        print('Erro ao verificar status financeiro: $e');
      }

      if (isOverdue && mounted) {
        // Bloquear acesso
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    color: AppTheme.accentRed, size: 28),
                const SizedBox(width: 10),
                const Text('Acesso Bloqueado'),
              ],
            ),
            content: const Text(
              'Sua mensalidade está vencida.\n\nPor favor, realize o pagamento para liberar seu acesso ao aplicativo.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Fecha dialog
                  _logout(); // Faz logout
                },
                child: Text(
                  'ENTENDI',
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
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
        // No dashboard principal, o botão voltar deve abrir o diálogo de logout
        // em vez de fechar o app silenciosamente.
        _logout();
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Área do Aluno',
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
                  color: Color(0xFF457B9D),
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
                                  const Color(0xFF457B9D),
                                  const Color(0xFF1D3557),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF457B9D).withOpacity(0.25),
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
                                          Icons.person_rounded,
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
                                        'Olá, ${_userData?['nome']?.split(' ')[0] ?? 'Aluno'}!',
                                        style: GoogleFonts.lato(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Foco no seu objetivo!',
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
                              'Meu Progresso',
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
                                title: 'Minhas Dietas',
                                icon: Icons.restaurant_menu_rounded,
                                color: const Color(0xFF2A9D8F),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MyDietScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Meus Treinos',
                                icon: Icons.fitness_center_rounded,
                                color: AppTheme.primaryRed,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MyWorkoutScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Avaliações Físicas',
                                icon: Icons.monitor_weight_rounded,
                                color: const Color(0xFFE65100),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const StudentReportsListScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Meu Perfil',
                                icon: Icons.person_rounded,
                                color: const Color(0xFF457B9D),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const StudentProfileScreen(),
                                    ),
                                  );
                                  _loadUserData();
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Card de avisos modernizado
                          BulletinBoardCard(
                            key: ValueKey(
                                _bulletinKey), // Usando a chave para forçar rebuild
                            baseColor: const Color(0xFF457B9D),
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
