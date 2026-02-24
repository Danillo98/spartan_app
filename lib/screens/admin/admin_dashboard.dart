import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SP
import '../../services/financial_service.dart'; // Import Service
import '../../services/auth_service.dart';
import '../../config/app_theme.dart';
import '../login_screen.dart';
import 'admin_users_screen.dart';
import 'financial/financial_dashboard_screen.dart';
import 'financial/monthly_payment_screen.dart';
import 'notice_manager_screen.dart';
import 'admin_profile_screen.dart';
import 'subscription_screen.dart'; // Add Import
import 'support_screen.dart'; // Import Support
import 'admin_turnstiles_screen.dart'; // Import Turnstiles
import 'admin_assessment_chooser_screen.dart';
import '../nutritionist/diets_list_screen.dart';
import '../trainer/workouts_list_screen.dart';
import '../../widgets/responsive_utils.dart';
import 'dart:async'; // Timer
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase
import '../../services/control_id_service.dart'; // Sync da Catraca

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

  Timer? _subscriptionTimer; // Timer para monitoramento silencioso

  RealtimeChannel? _alunosChannel;
  RealtimeChannel? _financialChannel;

  final Color _adminColor = const Color(0xFF1A1A1A); // Admin Black theme

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthService.checkBlockedStatus(context);
    });

    // Iniciar monitoramento silencioso de assinatura
    _startSubscriptionMonitor();

    // Sincronizar catraca em background (APENAS NO DESKTOP WINDOWS)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      ControlIdService.syncAllStudentsSilently();
      _startRealtimeControlIdSync();
    }
  }

  @override
  void dispose() {
    _subscriptionTimer?.cancel(); // Cancelar Timer ao sair
    _alunosChannel?.unsubscribe();
    _financialChannel?.unsubscribe();
    _animationController.dispose();
    super.dispose();
  }

  void _startRealtimeControlIdSync() {
    // Só inicia se for Windows Nativo
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;

    _alunosChannel = Supabase.instance.client
        .channel('public:users_alunos:dashboard')
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'users_alunos',
            callback: (payload) async {
              await Future.delayed(const Duration(milliseconds: 1000));

              final newRecord = payload.newRecord;
              if (newRecord.containsKey('id')) {
                final status = newRecord['status_financeiro'] as String?;
                final isBlocked = newRecord['is_blocked'] == true;
                ControlIdService.syncStudentRealtime(
                  newRecord['id'],
                  forcedStatus: status,
                  forcedIsBlocked: isBlocked,
                );
              }
            })
        .subscribe();

    _financialChannel = Supabase.instance.client
        .channel('public:financial_transactions:dashboard')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'financial_transactions',
            callback: (payload) async {
              await Future.delayed(const Duration(milliseconds: 1000));

              final record = payload.newRecord.isNotEmpty
                  ? payload.newRecord
                  : payload.oldRecord;

              if (record.containsKey('related_user_id')) {
                ControlIdService.syncStudentRealtime(record['related_user_id']);
              } else if (payload.eventType == PostgresChangeEvent.delete) {
                ControlIdService.syncAllStudentsSilently();
              }
            })
        .subscribe();
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

        // Após carregar usuário, checar notificações diárias
        _checkDailyNotifications();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Carregar dados do usuário SILENCIOSAMENTE (sem loading visual)
  /// Usado pelo _refreshDashboard para evitar piscar de tela
  Future<void> _silentLoadUserData() async {
    try {
      final data = await AuthService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userData = data;
          // NÃO modifica _isLoading - mantém tela visível
        });
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

    // 2. Recarregar dados SILENCIOSAMENTE (sem piscar!)
    await _silentLoadUserData();

    print('✅ Dashboard refreshed');
  }

  // Verificar se precisa rodar notificações automáticas (1x por dia)
  Future<void> _checkDailyNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRunDate = prefs.getString('last_overdue_check_date');
      final todayDate = DateTime.now().toIso8601String().split('T')[0];

      // Se ainda não rodou hoje (ou nunca rodou)
      if (lastRunDate != todayDate) {
        debugPrint(
            "📅 Executando verificação diária de inadimplência($todayDate)...");

        // Usar o serviço Financeiro para checar e notificar
        final result = await FinancialService.runOverdueCheckAndNotify();

        if (result['success'] == true) {
          debugPrint("✅ Verificação diária concluída: ${result['message']}");
          // Salvar data de hoje para não rodar de novo
          await prefs.setString('last_overdue_check_date', todayDate);
        } else {
          debugPrint("⚠️ Falha na verificação diária: ${result['message']}");
          // Opcional: Não salvar data para tentar de novo no próximo load?
          // Melhor salvar para não ficar tentando infinito se der erro persistente,
          // mas por segurança aqui só salvamos se sucesso.
        }
      } else {
        debugPrint("✅ Verificação diária já foi executada hoje.");
      }
    } catch (e) {
      debugPrint("❌ Erro no check diário: $e");
    }
  }

  void _startSubscriptionMonitor() {
    // Verificação inicial rápida
    _checkSubscriptionStatus();
    // Loop a cada 10 minutos (silencioso)
    _subscriptionTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _checkSubscriptionStatus();
    });
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Consulta leve apenas status e bloqueio
      final response = await Supabase.instance.client
          .from('users_adm')
          .select('assinatura_status, is_blocked, assinatura_tolerancia')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        final status = response['assinatura_status'];
        final isBlocked = response['is_blocked'] == true;

        // Verificar Tolerância
        bool toleranciaExpirada = false;
        final toleranciaStr = response['assinatura_tolerancia'];
        if (toleranciaStr != null) {
          final tolerancia = DateTime.tryParse(toleranciaStr);
          if (tolerancia != null && DateTime.now().isAfter(tolerancia)) {
            toleranciaExpirada = true;
          }
        }

        if (status == 'suspended' ||
            status == 'blocked' ||
            isBlocked ||
            toleranciaExpirada) {
          _showSubscriptionBlockedDialog();
        }
      }
    } catch (e) {
      print('Erro silent monitor: $e');
    }
  }

  void _showSubscriptionBlockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppTheme.accentRed, size: 28),
              SizedBox(width: 10),
              Text('Acesso Suspenso'),
            ],
          ),
          content: const Text(
            'Sua assinatura está suspensa ou bloqueada. Para recuperar o acesso ao painel Spartan, é necessário regularizar sua conta.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Redireciona para Assinatura em MODO TRAVADO
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) =>
                              const SubscriptionScreen(isLocked: true)),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  child: const Text(
                    'Renovar Agora',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
              _refreshDashboard();
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
                                          Icons.business_rounded,
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
                                title: 'Controle Financeiro',
                                icon: Icons.account_balance_wallet_rounded,
                                color: const Color(
                                    0xFF00695C), // Verde Petróleo/Gestão
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const FinancialDashboardScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Mensalidades',
                                icon: Icons.attach_money_rounded,
                                color:
                                    const Color(0xFF2E7D32), // Verde Dinheiro
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MonthlyPaymentScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Usuários',
                                icon: Icons.people_alt_rounded,
                                color: const Color(0xFF1976D2), // Azul Pessoas
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AdminUsersScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Nutrição',
                                icon: Icons.restaurant_menu_rounded,
                                color: const Color(0xFF4CAF50), // Verde Maçã
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const DietsListScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Treino',
                                icon: Icons.fitness_center_rounded,
                                color:
                                    const Color(0xFFD32F2F), // Vermelho Força
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const WorkoutsListScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Avaliações Físicas',
                                icon: Icons.monitor_weight_rounded,
                                color: const Color(0xFFE65100), // Laranja Saúde
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AdminAssessmentChooserScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Quadro de avisos',
                                icon: Icons.notifications_active_rounded,
                                color:
                                    const Color(0xFFFBC02D), // Amarelo Alerta
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const NoticeManagerScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Minhas Catracas',
                                icon: Icons.sensors_rounded,
                                color: const Color(0xFF673AB7), // Roxo Tech
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AdminTurnstilesScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Suporte',
                                icon: Icons.support_agent_rounded,
                                color: const Color(0xFF455A64), // Blue Grey
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SupportScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
                                },
                              ),
                              _buildModernFeatureCard(
                                title: 'Assinatura Spartan',
                                icon: Icons.verified_rounded,
                                color: const Color(0xFF212121), // Preto Premium
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SubscriptionScreen(),
                                    ),
                                  );
                                  _refreshDashboard();
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
