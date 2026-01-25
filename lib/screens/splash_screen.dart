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
    Future.delayed(const Duration(seconds: 3), _checkLoginStatus);
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;

    try {
      // Verificar se é uma sessão de password recovery
      final currentSession = SupabaseService.client.auth.currentSession;
      if (currentSession != null) {
        // Se temos sessão mas pode ser recovery, vamos tentar ver se é
        // um link de recuperação checando se temos dados do usuário
        try {
          final userData = await AuthService.getCurrentUserData();
          // Se falhar (network) vai pro catch do bloco principal

          if (userData == null && AuthService.isLoggedIn()) {
            // Logado mas sem dados no banco = provável recovery ou cadastro incompleto
            print(
                '⚠️ Sessão sem dados (possível recovery). Não redirecionando.');
            return;
          }

          // Se recuperou dados, fluxo normal abaixo
        } catch (e) {
          // Se der erro de rede aqui, vamos deixar cair no catch principal para retry
          rethrow;
        }
      }

      if (AuthService.isLoggedIn()) {
        final userData = await AuthService.getCurrentUserData();

        if (userData != null) {
          _navigateToDashboard(userData);
        } else {
          // Usuário existe no Auth mas não nas tabelas => Inconsistência
          print('❌ Usuário sem registro nas tabelas (e não é recovery).');
          await AuthService.logout();
          _navigateToLogin();
        }
      } else {
        _navigateToLogin();
      }
    } catch (e) {
      print('❌ Erro no Splash: $e');
      // Erro de conexão ou outro erro impeditivo -> Mostrar Retry
      _showRetryDialog();
    }
  }

  void _navigateToDashboard(Map<String, dynamic> userData) {
    if (!mounted) return;

    Widget targetScreen = const LoginScreen();
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

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _showRetryDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Erro de Conexão',
          style: TextStyle(
              color: AppTheme.primaryText, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
          style: TextStyle(color: AppTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SupabaseService.client.auth.signOut();
              Navigator.pop(context);
              _navigateToLogin();
            },
            child: const Text('Sair da Conta',
                style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkLoginStatus(); // Retry
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
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
