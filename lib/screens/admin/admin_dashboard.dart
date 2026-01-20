import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../config/app_theme.dart';
import '../login_screen.dart';
import 'admin_users_screen.dart';
import 'financial/financial_dashboard_screen.dart';
import 'financial/monthly_payment_screen.dart';
import 'assessment_list_screen.dart';
import 'notice_manager_screen.dart';
import 'admin_profile_screen.dart';
import '../../widgets/responsive_utils.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Color _adminColor = const Color(0xFF1A1A1A); // Admin Black theme

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
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.account_circle_rounded, size: 28),
          color: AppTheme.secondaryText,
          tooltip: 'Meu Perfil',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminProfileScreen(),
              ),
            );
            _loadUserData();
          },
        ),
        title: Text(
          'Administrador',
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
          ? Center(
              child: CircularProgressIndicator(
                color: _adminColor,
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
                        // Card de boas-vindas Admin
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _adminColor,
                                const Color(0xFF333333),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: _adminColor.withOpacity(0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
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
                                        Icons.business_rounded,
                                        size: 36,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _userData?['academia'] ??
                                          'Minha Academia',
                                      style: GoogleFonts.lato(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Gerencie sua academia com excelência',
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

                        // Grid de funcionalidades
                        ResponsiveGrid(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _buildModernFeatureCard(
                              title: 'Mensalidades',
                              icon: Icons.attach_money_rounded,
                              color: const Color(0xFF2E7D32), // Verde Dinheiro
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const MonthlyPaymentScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildModernFeatureCard(
                              title: 'Usuários',
                              icon: Icons.people_alt_rounded,
                              color: const Color(0xFF1976D2), // Azul Pessoas
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminUsersScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildModernFeatureCard(
                              title: 'Controle Financeiro',
                              icon: Icons.account_balance_wallet_rounded,
                              color: const Color(
                                  0xFF00695C), // Verde Petróleo/Gestão
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const FinancialDashboardScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildModernFeatureCard(
                              title: 'Avaliações físicas',
                              icon: Icons.monitor_weight_rounded,
                              color: const Color(0xFFE65100), // Laranja Saúde
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AssessmentListScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildModernFeatureCard(
                              title: 'Quadro de avisos',
                              icon: Icons.notifications_active_rounded,
                              color: const Color(0xFFFBC02D), // Amarelo Alerta
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NoticeManagerScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildModernFeatureCard(
                              title: 'Assinatura Spartan',
                              icon: Icons.verified_rounded,
                              color: const Color(0xFF212121), // Preto Premium
                              onTap: () {
                                _showComingSoon(context, 'Assinatura Spartan');
                              },
                            ),
                          ],
                        ),

                        // Espaço extra no final
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Em breve: $feature'),
        backgroundColor: _adminColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildModernFeatureCard({
    required String title,
    required IconData icon,
    required Color color, // Novo parâmetro
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
                  color: color.withOpacity(0.1), // Usar cor passada
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color, // Usar cor passada
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
