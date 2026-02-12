import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../services/user_service.dart';
import '../../services/payment_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_role.dart';
import '../login_screen.dart';
import 'admin_dashboard.dart';

// Conditional import for web
import 'subscription_screen_web_helper.dart'
    if (dart.library.io) 'subscription_screen_stub.dart' as web_helper;

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  String _currentPlan = '';
  String? _selectedPlan; // Para controlar qual card está selecionado
  bool _isLoading = true;
  DateTime? _expiresAt;
  bool _wentToStripe = false; // Flag para saber se foi para o Stripe
  StreamSubscription? _focusSubscription;
  UserRole? _userRole; // Armazenar role do usuário

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupWebFocusListener();
    _loadSubscriptionData();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final role = await AuthService.getCurrentUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusSubscription?.cancel();
    super.dispose();
  }

  // Configura listener de foco para Web
  void _setupWebFocusListener() {
    if (kIsWeb) {
      _focusSubscription = web_helper.onWindowFocus().listen((_) {
        if (_wentToStripe) {
          _onReturnFromStripe();
        }
      });
    }
  }

  // Detecta quando o app volta ao foco (usuário voltou do Stripe) - Mobile
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wentToStripe) {
      _onReturnFromStripe();
    }
  }

  // Chamado quando o usuário volta do Stripe (web ou mobile)
  void _onReturnFromStripe() async {
    _wentToStripe = false;

    // 1. Verificação Imediata
    final initialRole = await AuthService.getCurrentUserRole();
    if (initialRole == UserRole.admin) {
      _showPaymentSuccessDialog();
      return;
    }

    // 2. Polling de 6 tentativas a cada 3 segundos com Diálogo Cancelável
    int attempts = 0;
    bool success = false;
    bool pollingCancelled = false;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: true, // Agora permite fechar clicando fora
        builder: (ctx) => PopScope(
          onPopInvoked: (didPop) {
            if (didPop) pollingCancelled = true;
          },
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const CircularProgressIndicator(color: AppTheme.primaryRed),
                const SizedBox(height: 24),
                const Text('Verificando status...',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                const Text(
                  'Aguardando o Stripe confirmar sua transação. Isso pode levar alguns segundos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.secondaryText),
                ),
                const SizedBox(height: 8),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () {
                    pollingCancelled = true;
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    'AINDA NÃO PAGUEI / VOLTAR',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ).then((_) {
        // Se o usuário fechou o diálogo (por qualquer meio), para o polling
        pollingCancelled = true;
      });
    }

    while (attempts < 6 && !success && !pollingCancelled) {
      final role = await AuthService.getCurrentUserRole();
      if (role == UserRole.admin) {
        success = true;
        break;
      }

      attempts++;
      if (!pollingCancelled) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    // Fecha o loading se ele ainda estiver aberto e tivemos sucesso
    if (mounted && success && !pollingCancelled) {
      Navigator.of(context).pop();
    }

    if (success) {
      _showPaymentSuccessDialog();
    } else {
      _loadSubscriptionData();
      _checkUserRole();

      if (mounted && !pollingCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Confirmação pendente. Se já pagou, sua conta será liberada em instantes.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            const Text('Pagamento Confirmado!'),
          ],
        ),
        content: const Text(
          'Sua assinatura foi processada com sucesso. Bem-vindo ao Spartan App!',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AdminDashboard()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: Colors.white,
            ),
            child: const Text('ACESSAR DASHBOARD'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSubscriptionData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      // Se for visitante, checkPlanLimitStatus falha pois não tem dados em users_adm
      if (_userRole == UserRole.visitor) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final planStatus = await UserService.checkPlanLimitStatus();
      final subStatus = await UserService.getSubscriptionStatus();

      if (mounted) {
        setState(() {
          _currentPlan = planStatus['plan'] ?? 'Prata';

          // Parse da data de vencimento
          if (subStatus['expirada'] != null) {
            _expiresAt = DateTime.tryParse(subStatus['expirada']);
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleCardTap(String planName) {
    setState(() {
      _selectedPlan = planName;
    });
  }

  // Formatar data para exibição
  String _formatDate(DateTime? date) {
    if (date == null) return 'Não definido';
    return DateFormat('dd/MM/yyyy', 'pt_BR').format(date);
  }

  // Popup de confirmação para upgrade/downgrade/renovação
  Future<void> _showPlanChangeConfirmation(String newPlan) async {
    // Se for visitante, não precisa de confirmação (está assinando pela primeira vez)
    if (_userRole == UserRole.visitor) {
      await _initiateCheckout(newPlan);
      return;
    }

    final bool isMyPlan = _currentPlan.toLowerCase() == newPlan.toLowerCase();
    final String actionText = isMyPlan ? 'RENOVAR' : 'TROCAR PARA';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange[700], size: 28),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Atenção!',
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                      color: Colors.black87, fontSize: 15, height: 1.5),
                  children: [
                    const TextSpan(text: 'Seu plano atual: '),
                    TextSpan(
                      text: _currentPlan.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                      color: Colors.black87, fontSize: 15, height: 1.5),
                  children: [
                    const TextSpan(text: 'Vencimento: '),
                    TextSpan(
                      text: _formatDate(_expiresAt),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryRed),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMyPlan
                          ? 'Ao confirmar a RENOVAÇÃO:'
                          : 'Ao confirmar a troca para ${newPlan.toUpperCase()}:',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Seu plano atual será cancelado imediatamente',
                        style: TextStyle(fontSize: 13)),
                    Text(
                      '• Novo vencimento será: ${_formatDate(DateTime.now().add(const Duration(days: 30)))} (30 dias)',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (!isMyPlan)
                      const Text('• Não há reembolso do período não utilizado',
                          style: TextStyle(fontSize: 13, color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D1D1F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('$actionText e Pagar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _initiateCheckout(newPlan);
    }
  }

  // Iniciar checkout do Stripe
  Future<void> _initiateCheckout(String planName) async {
    try {
      setState(() => _isLoading = true);

      final user = AuthService.getCurrentUser();
      if (user == null) throw Exception('Usuário não autenticado');

      final priceId = PaymentService.getPriceIdByName(planName);

      // BUSCA DE DADOS PENDENTES (Smart Merge v3 - Client Side)
      Map<String, String> checkoutMetadata = {
        'plano_selecionado': planName,
        'is_upgrade':
            (_currentPlan.toLowerCase() != planName.toLowerCase()).toString(),
      };

      if (_userRole == UserRole.visitor) {
        print('🔍 Buscando dados de cadastro pendente para o checkout...');
        final pendingRes = await Supabase.instance.client
            .from('pending_registrations')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (pendingRes != null) {
          print('✅ Dados pendentes encontrados! Anexando ao checkout...');
          checkoutMetadata.addAll({
            'nome': pendingRes['full_name'] ?? '',
            'academia': pendingRes['gym_name'] ?? '',
            'telefone': pendingRes['phone'] ?? '',
            'cnpj_academia': pendingRes['cnpj'] ?? '',
            'cpf_responsavel': pendingRes['cpf'] ?? '',
            'endereco': pendingRes['address_street'] ?? '',
          });
        }
      }

      final checkoutUrl = await PaymentService.createCheckoutSession(
        priceId: priceId,
        userId: user.id,
        userEmail: user.email ?? '',
        metadata: checkoutMetadata,
      );

      if (checkoutUrl.isNotEmpty) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          // Marcar que foi para o Stripe para fazer refresh ao voltar
          _wentToStripe = true;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Não foi possível abrir o link de pagamento');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao iniciar pagamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _userRole != UserRole.visitor, // Bloqueia se for visitante
      onPopInvoked: (didPop) {
        if (!didPop && _userRole == UserRole.visitor) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Por favor, conclua sua assinatura para acessar o sistema.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _userRole == UserRole.visitor
              ? null // Esconde o X se for visitante
              : IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () {
                    // Verifica se pode voltar, senão vai para dashboard
                    if (Navigator.of(context).canPop()) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminDashboard()),
                        (route) => false,
                      );
                    }
                  },
                ),
          title: Text(
            'ASSINATURA SPARTAN',
            style: GoogleFonts.cinzel(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: _userRole == UserRole.visitor
              ? [
                  TextButton.icon(
                    onPressed: () async {
                      await AuthService.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon:
                        const Icon(Icons.logout, color: Colors.grey, size: 18),
                    label: const Text('Sair',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ]
              : null,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryRed))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    // LOGO (Responsiva: Desktop 300, Mobile 150)
                    Image.asset(
                      'assets/images/splash_logo.png',
                      height:
                          MediaQuery.of(context).size.width > 600 ? 300 : 150,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sua Evolução Não Pode Parar',
                      style: GoogleFonts.lato(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'O crescimento da sua academia exige ferramentas mais poderosas. Escolha o plano que combina com sua ambição.',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // LISTA HORIZONTAL
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(
                          left: 24, right: 24, top: 25, bottom: 40),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width - 48,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // PRATA
                            _buildInteractableCard(
                              title: 'PRATA',
                              tag: 'VALIDAÇÃO',
                              price: '129,90',
                              description:
                                  'Ideal para academias de pequeno porte.',
                              bgColor: const Color(0xFFC5D1D8),
                              borderColor: const Color(0xFF5A7D8F),
                              cardColorName: 'Prata',
                              features: [
                                'Módulos: Administrador, Nutricionista, Personal Trainer e Aluno.',
                                'Dietas, Relatórios Físicos e Treinos.',
                                'Monitoramento de Mensalidades, Controle Financeiro, Fluxo de Caixa e Relatórios Mensais e Anuais em PDF.',
                                'Suporta até 200 alunos.',
                              ],
                            ),
                            const SizedBox(width: 24),

                            // OURO
                            _buildInteractableCard(
                              title: 'OURO',
                              tag: 'MAIS ESCOLHIDO', // Tag interna
                              price: '239,90',
                              description:
                                  'Para quem já validou e precisa escalar.',
                              bgColor: const Color(0xFFFBF9F2),
                              borderColor: const Color(0xFFD4AF37),
                              cardColorName: 'Ouro',
                              features: [
                                'Módulos: Administrador, Nutricionista, Personal Trainer e Aluno.',
                                'Dietas, Relatórios Físicos e Treinos.',
                                'Monitoramento de Mensalidades, Controle Financeiro, Fluxo de Caixa e Relatórios Mensais e Anuais em PDF.',
                                'Suporta até 500 alunos.',
                                'Maior margem de lucro por aluno.',
                                'Estrutura para crescimento forte.'
                              ],
                            ),
                            const SizedBox(width: 24),

                            // PLATINA
                            _buildInteractableCard(
                              title: 'PLATINA',
                              tag: 'INFINITO',
                              price: '349,90',
                              description:
                                  'A liberdade absoluta. O céu é o limite.',
                              bgColor: const Color(0xFFE8F6F9),
                              borderColor: const Color(0xFF00BCD4),
                              cardColorName: 'Platina',
                              features: [
                                'Módulos: Administrador, Nutricionista, Personal Trainer e Aluno.',
                                'Dietas, Relatórios Físicos e Treinos Integrados.',
                                'Monitoramento de Mensalidades, Controle Financeiro, Fluxo de Caixa e Relatórios Mensais e Anuais em PDF.',
                                'Alunos ILIMITADOS.',
                                'O céu é o limite! Aqui o lucro é exponencial.',
                                'Estrutura para grandes empreendimentos.'
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // === BOTÕES LEGAIS E CANCELAMENTO ===
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Política de Privacidade
                          TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse('/politicas/'),
                              mode: LaunchMode.externalApplication,
                              webOnlyWindowName: '_blank',
                            ),
                            icon: const Icon(Icons.lock_outline, size: 16),
                            label: const Text('Política de Privacidade'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text('|', style: TextStyle(color: Colors.grey[300])),
                          // Termos de Uso
                          TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse('/termos/'),
                              mode: LaunchMode.externalApplication,
                              webOnlyWindowName: '_blank',
                            ),
                            icon: const Icon(Icons.description_outlined,
                                size: 16),
                            label: const Text('Termos de Uso'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text('|', style: TextStyle(color: Colors.grey[300])),
                          // Cancelar Assinatura (Vermelho)
                          TextButton.icon(
                            onPressed: _showCancelSubscriptionDialog,
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Cancelar Assinatura'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red[700],
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  // Popup de confirmação de cancelamento
  void _showCancelSubscriptionDialog() {
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
              child: Text(
                'Cancelar Assinatura',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Você tem certeza que deseja cancelar sua assinatura?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.money_off, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Não haverá reembolso de dias restantes.',
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.delete_forever,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Todas as informações relacionadas ao Proprietário e sua Academia serão deletadas PERMANENTEMENTE do sistema.',
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Esta ação é irreversível!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmCancelSubscription();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar Cancelamento'),
          ),
        ],
      ),
    );
  }

  // Confirmação final de cancelamento
  Future<void> _confirmCancelSubscription() async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      // Buscar ID do usuário atual
      final userData = await AuthService.getCurrentUserData();
      final userId = userData?['id'];

      if (userId == null) {
        throw Exception('Usuário não encontrado');
      }

      // Chamar serviço de cancelamento
      final result = await PaymentService.cancelSubscription(userId: userId);

      // Fechar loading
      if (mounted) Navigator.of(context).pop();

      if (result['success'] == true) {
        // Mostrar sucesso e fazer logout
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Assinatura Cancelada',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sua assinatura foi cancelada com sucesso.',
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.orange, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Foi um prazer ter você conosco e é uma pena te perder. Esperamos te ver por aqui novamente!😢',
                            style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    // Fazer logout
                    await AuthService.signOut();
                    if (mounted) {
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Entendi'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Erro desconhecido');
      }
    } catch (e) {
      // Fechar loading se ainda estiver aberto
      if (mounted) Navigator.of(context).pop();

      // Mostrar erro
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildInteractableCard({
    required String title,
    required String tag,
    required String price,
    required String description,
    required Color bgColor,
    required Color borderColor,
    required String
        cardColorName, // Nome interno para comparação (ex: 'Prata', 'Ouro')
    required List<String> features,
  }) {
    final width = 340.0;

    // Lógica de Estado
    // Normalizamos para comparar com o backend (que retorna Prata/Ouro/Platina capitalize ou lower)
    final bool isMyPlan =
        _currentPlan.toLowerCase() == cardColorName.toLowerCase();

    // Seleção: Se o nome deste card for igual ao _selectedPlan
    final bool isSelected = _selectedPlan == cardColorName;

    // Efeito LED/Brilho quando selecionado
    final List<BoxShadow> shadows = isSelected
        ? [
            BoxShadow(
              color: borderColor.withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            )
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ];

    final borderDisplay = isSelected
        ? Border.all(
            color: borderColor, width: 3) // Borda mais grossa se selecionado
        : Border.all(color: borderColor.withOpacity(0.5), width: 1.5);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () {
            _handleCardTap(cardColorName);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: borderDisplay,
              boxShadow: shadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: borderColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: borderColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: borderColor.withOpacity(0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Indicador de Seleção (Radio Visual)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? borderColor : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? borderColor
                              : borderColor.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Preço
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'R\$',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      TextSpan(
                        text: ' $price',
                        style: GoogleFonts.inter(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: -1.0,
                        ),
                      ),
                      TextSpan(
                        text: ' /mês',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),

                const SizedBox(height: 24),
                Divider(color: borderColor.withOpacity(0.3)),
                const SizedBox(height: 24),

                // Features
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.flash_on_rounded,
                            size: 18,
                            color: borderColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF444444),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 16),

                // Botão "FAZER UPGRADE" (Lógica Pedida)
                // Desativado se o card não for selecionado.
                // Ativado se for selecionado.
                SizedBox(
                  width: double.infinity,
                  child: IgnorePointer(
                    ignoring: !isSelected, // Ignora clique se não selecionado
                    child: ElevatedButton(
                      onPressed: isSelected
                          ? () {
                              // Chamar popup de confirmação
                              _showPlanChangeConfirmation(cardColorName);
                            }
                          : null, // Visualmente desativado (null onPressed faz o estilo disabled)
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D1D1F),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.grey[300], // Cor Cinza se desativado
                        disabledForegroundColor: Colors.grey[500],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isMyPlan ? 'RENOVAR ASSINATURA' : 'FAZER UPGRADE',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tag Flutuante "PLANO ATUAL" (Apenas se for o plano do usuário)
        if (isMyPlan)
          Positioned(
            top: -15,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: borderColor, // Usa a cor do tema do card
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Text(
                  _expiresAt != null
                      ? 'PLANO ATUAL - VENCIMENTO: ${_formatDate(_expiresAt)}'
                      : 'PLANO ATUAL',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
