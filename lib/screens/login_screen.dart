import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_role.dart';
import '../config/app_theme.dart';
import 'role_login_screen.dart';
import '../config/app_version.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToLogin(BuildContext context, UserRole role, String roleTitle) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RoleLoginScreen(role: role, roleTitle: roleTitle),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.lightGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      // Logo e título
                      _buildHeader(),

                      const SizedBox(height: 20),

                      // Cards de perfis
                      _buildRoleCard(
                        context,
                        'Administrador',
                        'Gerencie sua academia',
                        Icons.admin_panel_settings_rounded,
                        const Color(0xFF1A1A1A),
                        UserRole.admin,
                        0,
                      ),

                      const SizedBox(height: 20),

                      _buildRoleCard(
                        context,
                        'Nutricionista',
                        'Crie dietas personalizadas',
                        Icons.restaurant_menu_rounded,
                        const Color(0xFF2A9D8F), // Verde mais sóbrio
                        UserRole.nutritionist,
                        100,
                      ),

                      const SizedBox(height: 20),

                      _buildRoleCard(
                        context,
                        'Personal Trainer',
                        'Monte treinos eficientes',
                        Icons.fitness_center_rounded,
                        AppTheme.primaryRed,
                        UserRole.trainer,
                        200,
                      ),

                      const SizedBox(height: 20),

                      _buildRoleCard(
                        context,
                        'Aluno',
                        'Acompanhe seu progresso',
                        Icons.person_rounded,
                        const Color(0xFF457B9D), // Azul mais sóbrio
                        UserRole.student,
                        300,
                      ),

                      const SizedBox(height: 20),

                      // Footer
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo com glow dourado suave
        // Logo
        Image.asset(
          'assets/images/splash_logo.png',
          width: 240,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.fitness_center_rounded,
              size: 80,
              color: AppTheme.primaryText,
            );
          },
        ),
        const SizedBox(height: 1),

        Text(
          'Escolha seu perfil',
          style: GoogleFonts.lato(
            fontSize: 16,
            color: AppTheme.secondaryText,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    UserRole role,
    int delay,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: _HoverableRoleCard(
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
        onTap: () => _navigateToLogin(context, role, title),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          height: 1,
          width: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppTheme.primaryGold.withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Versão ${AppVersion.current}',
          style: GoogleFonts.lato(fontSize: 12, color: AppTheme.hintText),
        ),
      ],
    );
  }
}

class _HoverableRoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HoverableRoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HoverableRoleCard> createState() => _HoverableRoleCardState();
}

class _HoverableRoleCardState extends State<_HoverableRoleCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 100,
          transform: Matrix4.identity()..scale(_isHovering ? 1.02 : 1.0),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: AppTheme.cardRadius,
            border: Border.all(
              color: _isHovering ? widget.color : AppTheme.mediumGrey,
              width: _isHovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovering
                    ? widget.color.withOpacity(0.15)
                    : Colors.black.withOpacity(0.05),
                blurRadius: _isHovering ? 20 : 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Ícone de fundo decorativo (sutil)
              Positioned(
                right: -15,
                top: -15,
                child: Opacity(
                  opacity: 0.05,
                  child: Icon(widget.icon, size: 120, color: widget.color),
                ),
              ),

              // Conteúdo
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    // Ícone principal
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isHovering
                            ? widget.color
                            : widget.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 30,
                        color: _isHovering ? Colors.white : widget.color,
                      ),
                    ),

                    const SizedBox(width: 20),

                    // Textos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Seta
                    AnimatedPadding(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.only(left: _isHovering ? 10 : 0),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _isHovering
                            ? widget.color
                            : AppTheme.secondaryText.withOpacity(0.5),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
