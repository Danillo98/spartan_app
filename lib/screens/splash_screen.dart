import 'package:flutter/material.dart';
import 'dart:async';
import '../config/app_theme.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'admin/admin_dashboard.dart';
import 'nutritionist/nutritionist_dashboard.dart';
import 'trainer/trainer_dashboard.dart';
import 'student/student_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();

    // Verificação de login após 3 segundos
    Timer(const Duration(seconds: 3), () async {
      if (mounted) {
        // Verificar se é uma sessão de password recovery
        final currentSession = SupabaseService.client.auth.currentSession;
        if (currentSession != null) {
          // Verificar se o access token contém informações de recovery
          // Quando é recovery, o Supabase não cria registro nas tabelas de usuário
          try {
            final userData = await AuthService.getCurrentUserData();
            if (userData == null && AuthService.isLoggedIn()) {
              // Usuário logado mas sem dados = sessão de recovery
              print('⚠️ Sessão de recovery detectada. Não redirecionando.');
              // Não fazer nada, deixar o AuthListener ou DeepLink handler cuidar
              return;
            }
          } catch (e) {
            print('⚠️ Erro ao verificar dados do usuário: $e');
            // Se der erro ao buscar dados, pode ser recovery também
            if (AuthService.isLoggedIn()) {
              print('⚠️ Possível sessão de recovery. Não redirecionando.');
              return;
            }
          }
        }

        Widget targetScreen = const LoginScreen();

        if (AuthService.isLoggedIn()) {
          try {
            final userData = await AuthService.getCurrentUserData();
            if (userData != null) {
              final role = userData['role'];
              switch (role) {
                case 'admin':
                  targetScreen = const AdminDashboard();
                  break;
                case 'nutritionist':
                  targetScreen = const NutritionistDashboard();
                  break;
                case 'trainer':
                  targetScreen = const TrainerDashboard();
                  break;
                case 'student':
                  targetScreen = const StudentDashboard();
                  break;
              }
            }
          } catch (e) {
            print('Erro ao recuperar dados do usuário no splash: $e');
            // Mantém targetScreen como LoginScreen
          }
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  targetScreen,
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pegando as dimensões da tela
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      // Limitando a largura máxima para que não fique gigante no PC
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Image.asset(
                          'assets/images/splash_logo.png',
                          // Não forçamos width aqui, deixamos o ConstrainedBox limitar
                          // e o fit contain garantir a proporção
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: 45,
              height: 45,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                strokeWidth: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
