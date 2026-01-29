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
import 'services/cache_manager.dart';
// import 'services/notification_service.dart';
import 'config/app_theme.dart';
import 'package:app_links/app_links.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Configurar Instância Única no Windows
  if (!kIsWeb && Platform.isWindows) {
    try {
      await WindowsSingleInstance.ensureSingleInstance(
          args, "com.example.spartan_app_unique_id", onSecondWindow: (args) {
        print("Segunda instância detectada! Argumentos recebidos: $args");
        // A segunda instância será fechada automaticamente, mas antes passa os args
        // O pacote windows_single_instance não reabre automaticamente a janela se estiver minimizada,
        // mas garante que não abre outra.
        // Para tratar o deep link recebido na segunda instância, precisamos que a primeira instância
        // esteja escutando. O flutter_single_instance não passa os dados via Stream automaticamente?
        // Na verdade, o callback onSecondWindow roda na PRIMEIRA instância quando a segunda tenta abrir.

        // Se vier um argumento que parece um link, podemos processar manualmente?
        // Mas com 'app_links', ele deve capturar também.
        // O comportamento padrão do windows_single_instance é trazer a janela pra frente?
        // Sim, normalmente traz.
      });
    } catch (e) {
      print("Erro ao configurar Windows Single Instance: $e");
    }
  }

  // Inicializa o Supabase
  await SupabaseService.initialize();

  // Inicializa o Cache Manager
  try {
    await CacheManager().init();
    print("✅ Cache Manager inicializado com sucesso");
  } catch (e) {
    print("❌ Erro ao inicializar Cache Manager: $e");
  }

  // Inicializar Notificações (OneSignal)
  try {
    // await NotificationService.init();
    // Comentado para evitar erro se não tiver configurado ainda
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

  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _checkInitialLink(); // Verificar link inicial ANTES de tudo
    _setupDeepLinks(); // Novo método robusto
    _setupAuthListener();
  }

  // Verificar se o app foi aberto com um deep link
  Future<void> _checkInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        print('🔗 Link inicial detectado: $initialUri');
        // Aguardar um frame para garantir que o navigator está pronto
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLink(initialUri);
        });
      }
    } catch (e) {
      print('❌ Erro ao verificar link inicial: $e');
    }
  }

  // Listener nativo para Deep Links (Desktop/Mobile)
  void _setupDeepLinks() {
    _appLinks.uriLinkStream.listen((uri) {
      print('🔗 Deep Link recebido: $uri');
      _handleDeepLink(uri);
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    print('🔗 Deep Link Bruto: $uri');

    // Caso 1: Custom Scheme (io.supabase.spartanapp://reset-password?token=...)
    if (uri.scheme == 'io.supabase.spartanapp' &&
        (uri.host == 'reset-password' || uri.path.contains('reset-password'))) {
      final token = uri.queryParameters['token'];
      // Alguns deep links podem vir como fragment (login implicito)
      final fragmentToken = Uri.splitQueryString(uri.fragment)['access_token'];

      final finalToken = token ?? fragmentToken;

      if (finalToken != null) {
        print('🔐 Custom Scheme Reset detectado! Token: $finalToken');
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              token: finalToken,
            ),
          ),
          (route) => false,
        );
        return;
      }
    }

    // Caso 2: Fragmento Supabase (Hash)
    final fragment = uri.fragment;
    if (fragment.contains('type=recovery')) {
      // Tentativa de parse manual do fragmento
      // access_token=xxx&refresh_token=yyy&type=recovery...
      final params = Uri.splitQueryString(fragment);
      final accessToken = params['access_token'];

      if (accessToken != null) {
        print('🔐 Recuperação de senha via Fragment detectada!');
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              token: accessToken,
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  void _setupAuthListener() {
    // Listener para mudanças no estado de autenticação
    SupabaseService.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      print('🔔 Auth Event: $event');

      // 1. EVENTO ESPECÍFICO DE RECUPERAÇÃO DE SENHA
      if (event == AuthChangeEvent.passwordRecovery) {
        // session pode ser null no início, mas se o evento disparou,
        // o supabase client deve ter token em memória ou a sessão está sendo recuperada.
        // Se session vier null, pode ser um problema, mas vamos tentar pegar currentSession

        final currentSession =
            SupabaseService.client.auth.currentSession ?? session;

        print('🔐 Evento de Password Recovery detectado!');

        if (currentSession != null) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(
                token: currentSession.accessToken,
              ),
            ),
            (route) => false,
          );
        } else {
          print(
              '⚠️ Sessão nula no evento Password Recovery. Aguardando listener de DeepLink...');
        }
        return;
      }

      // 2. Outros eventos de login (confirmação de email, etc)
      if (event == AuthChangeEvent.signedIn && session != null) {
        _startBlockListeners(session.user.id); // <--- Iniciar monitoramento

        print('📧 Usuário logado. Verificando token de confirmação...');

        // Tentar pegar token da URL base (funciona melhor na Web, mas tentamos aqui)
        final uri = Uri.base;
        final token = uri.queryParameters['token'];

        // IGNORAR se for rota de reset de senha
        final isResetRoute = uri.path.contains('/reset-password') ||
            uri.fragment.contains('/reset-password');

        if (token != null && !isResetRoute) {
          print(
              '🔄 Token encontrado na URL base e NÃO é reset. Navegando para confirmação...');

          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => EmailConfirmationScreen(token: token),
            ),
            (route) => false,
          );
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _cancelBlockListeners(); // <--- Parar monitoramento
      }
    });

    // Se já estiver logado ao iniciar
    final session = SupabaseService.client.auth.currentSession;
    if (session != null) {
      _startBlockListeners(session.user.id);
    }
  }

  // --- Lógica de Monitoramento de Bloqueio (Realtime) ---
  final List<RealtimeChannel> _blockChannels = [];

  void _startBlockListeners(String userId) {
    _cancelBlockListeners(); // Limpar anteriores

    print('🛡️ Iniciando monitoramento de bloqueio para: $userId');

    // Monitorar Users Alunos
    _subscribeToBlockTable('users_alunos', userId);
    // Monitorar Users Personal
    _subscribeToBlockTable('users_personal', userId);
    // Monitorar Users Nutricionista
    _subscribeToBlockTable('users_nutricionista', userId);
    // Monitorar Users Adm (Opcional)
    _subscribeToBlockTable('users_adm', userId);
  }

  void _subscribeToBlockTable(String table, String userId) {
    try {
      final channel = SupabaseService.client
          .channel('public:$table:id=eq:$userId')
          .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: table,
              filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'id',
                  value: userId),
              callback: (payload) {
                final newRecord = payload.newRecord;
                if (newRecord['is_blocked'] == true) {
                  _handleUserBlocked();
                }
              })
          .subscribe();

      _blockChannels.add(channel);
    } catch (e) {
      print('Erro ao subscrever em $table: $e');
    }
  }

  void _cancelBlockListeners() {
    for (var channel in _blockChannels) {
      SupabaseService.client.removeChannel(channel);
    }
    _blockChannels.clear();
  }

  void _handleUserBlocked() {
    print('🚫 USUÁRIO BLOQUEADO EM TEMPO REAL!');
    // Exibir Dialog Bloqueante
    if (_navigatorKey.currentContext != null) {
      showDialog(
        context: _navigatorKey.currentContext!,
        barrierDismissible: false, // Não pode fechar clicando fora
        builder: (context) => AlertDialog(
          title: const Text('Acesso Bloqueado'),
          content: const Text(
              'Sua conta foi bloqueada temporariamente, entre em contato com a administração da academia.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Fecha dialog
                await _performLogout();
              },
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _performLogout() async {
    try {
      await SupabaseService.client.auth.signOut();
      await CacheManager().clearAll(); // <--- Corrected
      // Navegar para Login
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } catch (e) {
      print('Erro ao fazer logout forçado: $e');
    }
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

        if (settings.name == null) return null;

        final uri = Uri.parse(settings.name!);
        final token = uri.queryParameters['token'];

        // Rota de Redefinição de Senha
        if (uri.path.contains('/reset-password') ||
            settings.name!.startsWith('/reset-password')) {
          print('🔑 Rota de reset de senha detectada. Token: $token');
          if (token != null && token.isNotEmpty) {
            return MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(token: token),
            );
          }
        }

        // Rota de Confirmação de Email
        if (uri.path.contains('/confirm') ||
            settings.name!.startsWith('/confirm') ||
            settings.name!.contains('token=')) {
          // Mantendo compatibilidade com links antigos que só tinham o token
          print('🔑 Rota de confirmação detectada. Token: $token');
          if (token != null && token.isNotEmpty) {
            return MaterialPageRoute(
              builder: (context) => EmailConfirmationScreen(token: token),
            );
          }
        }

        return null;
      },
    );
  }
}
