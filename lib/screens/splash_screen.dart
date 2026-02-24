import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:universal_html/html.dart' as html;
import '../config/app_theme.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'admin/admin_dashboard.dart';
import 'admin/subscription_screen.dart';
import 'student/student_dashboard.dart';
import 'nutritionist/nutritionist_dashboard.dart';
import 'trainer/trainer_dashboard.dart';
import 'admin_register_screen.dart';
import '../services/version_service.dart';
import '../models/user_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // 1. CHECAR VERSÃO DO APP (Update Enforced) - DESATIVADO TEMPORARIAMENTE
    /*
    final newVersion = await VersionService.checkForUpdate();
    if (newVersion != null) {
      if (!mounted) return;
      _showUpdateDialog(newVersion);
      return; // Interrompe fluxo de login
    }
    */

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
            final user = AuthService.getCurrentUser();
            if (user != null) {
              // Verificar se é registro pendente (Lead Tracking)
              final pending = await SupabaseService.client
                  .from('pending_registrations')
                  .select()
                  .eq('id', user.id)
                  .maybeSingle();

              if (pending != null) {
                print('🚀 Cadastro Pendente detectado! Resumindo cadastro...');
                _navigateToRegisterResume(pending);
                return;
              }
            }

            // EXTRA: Verificar fragmento da URL diretamente para garantir que não navegamos para login em caso de recovery
            if (Uri.base.fragment.contains('type=recovery') ||
                Uri.base.toString().contains('type=recovery')) {
              print(
                  '🔐 Detection: Link de recuperação detectado no SplashScreen. Aguardando AuthListener...');
              return;
            }

            // Se não for nada disso, desloga por segurança
            print('❌ Usuário sem registro e sem pendência. Deslogando.');
            await AuthService.logout();
            _navigateToLogin();
            return;
          }

          // Se recuperou dados, fluxo normal abaixo
        } catch (e) {
          // Se der erro de rede aqui, vamos deixar cair no catch principal para retry
          rethrow;
        }
      }

      if (AuthService.isLoggedIn()) {
        try {
          // Adicionando timeout para evitar travamento infinito na Splash
          final userData = await AuthService.getCurrentUserData()
              .timeout(const Duration(seconds: 10));

          if (userData != null) {
            _navigateToDashboard(userData);
          } else {
            // Verificar registro pendente (Escape Hatch)
            final user = AuthService.getCurrentUser();
            if (user != null) {
              final pending = await SupabaseService.client
                  .from('pending_registrations')
                  .select()
                  .eq('id', user.id)
                  .maybeSingle()
                  .timeout(const Duration(seconds: 5));

              if (pending != null) {
                print('🚀 Cadastro Pendente detectado! Resumindo cadastro...');
                _navigateToRegisterResume(pending);
                return;
              }
            }

            // Usuário existe no Auth mas não nas tabelas => Inconsistência
            print('❌ Usuário sem registro nas tabelas (e não é recovery).');
            await AuthService.logout().timeout(const Duration(seconds: 5));
            _navigateToLogin();
          }
        } on TimeoutException catch (_) {
          print('⏰ Timeout na SplashScreen. Forçando logout para destravar.');
          await AuthService.logout();
          _navigateToLogin();
        } catch (e) {
          print('❌ Erro na SplashScreen: $e');
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

  Future<void> _navigateToDashboard(Map<String, dynamic> userData) async {
    if (!mounted) return;

    final role = userData['role'];
    final userId = userData['id'];
    final idAcademia = userData['id_academia'];

    // 1. VERIFICAÇÃO PARA VISITANTES (Cadastro Pendente)
    if (role == 'visitor') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      );
      return;
    }

    // 2. VERIFICAÇÃO DE ASSINATURA PARA ADMIN
    if (role == 'admin') {
      final subStatus = await AuthService.verificarStatusAssinatura(userId);
      final status = subStatus['status'];

      if (status == 'suspended' || status == 'pending_deletion') {
        // Admin suspenso -> Ir direto para tela de assinatura com popup
        _navigateToSubscriptionWithWarning(subStatus);
        return;
      } else if (status == 'grace_period' || status == 'warning') {
        // Aviso de Vencimento -> Mostrar aviso mas deixar entrar
        _showGracePeriodWarning(subStatus);
        // Continua para o dashboard normalmente após o aviso
      }
    }

    // VERIFICAÇÃO PARA SUBORDINADOS (nutri, personal, aluno)
    else if (idAcademia != null) {
      final academiaStatus =
          await AuthService.verificarAcademiaSuspensa(idAcademia);

      if (academiaStatus['suspended'] == true) {
        _showAcademiaSuspendedDialog(academiaStatus);
        return;
      }
    }

    // Navegação normal
    Widget targetScreen = const LoginScreen();

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

  // ADMIN SUSPENSO -> Tela de assinatura com aviso
  void _navigateToSubscriptionWithWarning(Map<String, dynamic> status) {
    if (!mounted) return;

    final diasRestantes = status['dias_para_exclusao'] ?? 60;

    // Mostrar popup primeiro, depois navegar
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Conta Suspensa',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sua assinatura está vencida e o acesso ao sistema está bloqueado.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Você tem $diasRestantes dias para renovar antes da exclusão permanente de todos os dados.',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.logout();
              if (mounted) _navigateToLogin();
            },
            child: const Text('Sair', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Renovar Assinatura'),
          ),
        ],
      ),
    );
  }

  // PERÍODO DE GRAÇA -> Aviso mas deixa entrar
  void _showGracePeriodWarning(Map<String, dynamic> status) {
    if (!mounted) return;

    final message = status['message'] ?? 'Período de graça ativo';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange[700],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Renovar',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
        ),
      ),
    );
  }

  // SUBORDINADO DE ACADEMIA SUSPENSA -> Popup de bloqueio
  void _showAcademiaSuspendedDialog(Map<String, dynamic> status) {
    if (!mounted) return;

    final nomeAcademia = status['academia'] ?? 'Academia';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red[700], size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Acesso Bloqueado',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'A academia "$nomeAcademia" está com pagamento pendente.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              'Entre em contato com o administrador da academia para regularizar o acesso.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.logout();
              if (mounted) _navigateToLogin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D1D1F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendi, Sair'),
          ),
        ],
      ),
    );
  }

  void _navigateToRegisterResume(Map<String, dynamic> pendingData) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AdminRegisterScreen(initialPendingData: pendingData),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _navigateToLogin() async {
    if (!mounted) return;

    // Lógica para salvar "eternamente" a escolha da role (UX solicitada)
    String? roleParam;

    // Tentar pegar da URL (tanto query quanto fragmento para PWA)
    final uri = Uri.base;
    roleParam = uri.queryParameters['role'];

    // Se no hash (comum em SPAs/PWAs)
    if (roleParam == null && uri.fragment.contains('role=')) {
      try {
        final frag = uri.fragment;
        final parts = frag.split('?');
        if (parts.length > 1) {
          final query = Uri.splitQueryString(parts.last);
          roleParam = query['role'];
        }
      } catch (e) {
        print('Erro ao parsear role do hash: $e');
      }
    }

    if (kIsWeb) {
      final storage = html.window.localStorage;

      if (roleParam == 'clear' || roleParam == 'admin') {
        storage.remove('saved_login_role');
        roleParam = null;
      } else if (roleParam != null) {
        storage['saved_login_role'] = roleParam;
      } else {
        roleParam = storage['saved_login_role'];
      }
    } else {
      final prefs = await SharedPreferences.getInstance();

      if (roleParam == 'clear' || roleParam == 'admin') {
        await prefs.remove('saved_login_role');
        roleParam = null;
      } else if (roleParam != null) {
        await prefs.setString('saved_login_role', roleParam);
      } else {
        roleParam = prefs.getString('saved_login_role');
      }
    }

    if (!mounted) return;

    Widget targetScreen = const LoginScreen();

    if (roleParam != null) {
      // Normalização para aceitar termos em Português ou Inglês (limpeza de URL)
      final normalizedRole = roleParam.toLowerCase().trim();

      if (normalizedRole == 'student' || normalizedRole == 'aluno') {
        targetScreen = const LoginScreen(roleFilter: UserRole.student);
      } else if (normalizedRole == 'nutritionist' ||
          normalizedRole == 'nutricionista') {
        targetScreen = const LoginScreen(roleFilter: UserRole.nutritionist);
      } else if (normalizedRole == 'trainer' ||
          normalizedRole == 'personal trainer' ||
          normalizedRole.contains('trainer')) {
        targetScreen = const LoginScreen(roleFilter: UserRole.trainer);
      }
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

  void _showUpdateDialog(String version) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.system_update, color: AppTheme.primaryRed, size: 30),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Atualização Disponível!',
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nova Versão: $version',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Uma nova versão do Spartan App está pronta para instalação. Atualize agora para continuar.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  VersionService.forceUpdate();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('ATUALIZAR AGORA'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
