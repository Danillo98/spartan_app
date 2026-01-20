import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/email_confirmation_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/nutritionist/diets_list_screen.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart'; // Added this import
import 'config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Supabase
  await SupabaseService.initialize();

  // Inicializar Notificações (OneSignal)
  // Requer onesignal_flutter adicionado ao pubspec.yaml
  try {
    await NotificationService.init();
  } catch (e) {
    print("Erro ao inicializar notificações: $e");
  }

  // Define orientação apenas retrato
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SpartanApp());
}

class SpartanApp extends StatefulWidget {
  const SpartanApp({super.key});

  @override
  State<SpartanApp> createState() => _SpartanAppState();
}

class _SpartanAppState extends State<SpartanApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    // Listener para mudanças no estado de autenticação
    SupabaseService.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      print('🔔 Auth Event: $event');

      // 1. EVENTO ESPECÍFICO DE RECUPERAÇÃO DE SENHA
      if (event == AuthChangeEvent.passwordRecovery && session != null) {
        print('🔐 Evento de Password Recovery detectado!');
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              token: session.accessToken,
            ),
          ),
          (route) => false,
        );
        return;
      }

      // 2. TENTATIVA DE DETECÇÃO VIA URL (BACKUP)
      // 2. Outros eventos de login (confirmação de email, etc)
      if (event == AuthChangeEvent.signedIn && session != null) {
        print('📧 Usuário logado. Verificando token de confirmação...');

        // Tentar pegar token da URL base (funciona melhor na Web, mas tentamos aqui)
        final uri = Uri.base;
        final token = uri.queryParameters['token'];

        if (token != null) {
          print(
              '🔄 Token encontrado na URL base. Navegando para tela de confirmação...');

          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => EmailConfirmationScreen(token: token),
            ),
            (route) => false,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spartan Gym',
      theme: AppTheme.theme,
      navigatorKey: _navigatorKey,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
      // Localização em português
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
      // Rotas nomeadas
      routes: {
        '/login': (context) => const LoginScreen(),
        '/diets': (context) => const DietsListScreen(),
        '/confirm': (context) {
          // Extrair token da URL
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final token = args?['token'] as String?;
          return EmailConfirmationScreen(token: token);
        },
      },
      // Processar deep links
      onGenerateRoute: (settings) {
        print('🔗 onGenerateRoute: ${settings.name}');

        // Se a rota tem um token, processar confirmação
        if (settings.name != null && settings.name!.contains('token=')) {
          try {
            final uri = Uri.parse(settings.name!);
            final token = uri.queryParameters['token'];

            print('🔑 Token extraído: $token');

            if (token != null && token.isNotEmpty) {
              print('✅ Navegando para EmailConfirmationScreen');
              return MaterialPageRoute(
                builder: (context) => EmailConfirmationScreen(token: token),
              );
            }
          } catch (e) {
            print('❌ Erro ao processar rota: $e');
          }
        }

        return null;
      },
    );
  }
}
