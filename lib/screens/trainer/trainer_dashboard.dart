import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../config/app_theme.dart';
import '../login_screen.dart';
import 'workouts_list_screen.dart';
import 'my_students_screen.dart';
import 'trainer_profile_screen.dart';
import '../../widgets/bulletin_board_card.dart';
import 'agenda/trainer_agenda_screen.dart';
import '../../widgets/responsive_utils.dart';

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
            'Personal Trainer',
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
                  color: AppTheme.primaryGold,
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    child: ResponsiveContainer(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card de boas-vindas
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryRed,
                                  AppTheme.accentRed.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: AppTheme.cardRadius,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryRed.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
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
                                          Icons.fitness_center_rounded,
                                          size: 32,
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
                                        'Olá, ${_userData?['name']?.split(' ')[0] ?? 'Personal'}!',
                                        style: GoogleFonts.lato(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Pronto para mais um dia de treino?',
                                        style: GoogleFonts.lato(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Grid de Menu
                          ResponsiveGrid(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildMenuCard(
                                title: 'Meus Alunos',
                                icon: Icons.people_alt_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MyStudentsScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuCard(
                                title: 'Fichas de Treino',
                                icon: Icons.fitness_center_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const WorkoutsListScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuCard(
                                title: 'Agenda',
                                icon: Icons.calendar_month_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const TrainerAgendaScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuCard(
                                title: 'Meu Perfil',
                                icon: Icons.person_rounded,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const TrainerProfileScreen(),
                                    ),
                                  );
                                  _loadUserData();
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Card de avisos
                          const BulletinBoardCard(
                              baseColor: AppTheme.primaryRed),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppTheme.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.cardRadius,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: AppTheme.primaryRed),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
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
