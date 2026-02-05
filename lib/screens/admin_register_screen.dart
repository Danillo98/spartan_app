import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_service.dart';
import '../services/document_validation_service.dart';
import '../config/app_theme.dart';

class AdminRegisterScreen extends StatefulWidget {
  final Map<String, dynamic>? initialPendingData;
  const AdminRegisterScreen({super.key, this.initialPendingData});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _academiaController = TextEditingController(); // NOVO
  final _cnpjController = TextEditingController();
  final _cpfController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // FocusNodes para controlar o foco
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Variáveis de Aceite Legal
  bool _termsAccepted = false;
  bool _privacyAccepted = false;

  int _currentStep = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Máscaras para formatação
  final _cnpjMask = MaskTextInputFormatter(
    mask: '##.###.###/####-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _cpfMask = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  String _selectedPlan = ''; // Plano selecionado
  String?
      _createdUserId; // Cache do usuário criado para evitar double-submit no Auth
  bool _pollingCancelled = false; // Flag para cancelar polling

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();

    // Lógica de Resumo de Cadastro
    if (widget.initialPendingData != null) {
      final data = widget.initialPendingData!;
      print('🔄 Resumindo cadastro para: ${data['email']}');

      _createdUserId = data['id'];
      _emailController.text = data['email'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _academiaController.text = data['gym_name'] ?? '';
      _nameController.text = data['full_name'] ?? '';
      _cnpjController.text = data['cnpj'] ?? '';
      _addressController.text = data['address_street'] ?? '';
      _selectedPlan = data['plan'] ?? '';

      // CNPJ Mask
      if (data['cnpj'] != null) {
        _cnpjMask.updateMask(
            mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
        // A máscara será aplicada no build pelo controller
      }

      // Definir passo atual (Garantir que não passe do limite)
      final savedStep = data['current_step'] as int? ?? 0;
      // Remapear passo do banco para o App se necessário
      // DB Step 1: Contato -> App Index 1
      // DB Step 2: Dados? (Não, Step 1 do App é Dados)

      // Vamos usar uma lógica simples:
      _currentStep = savedStep;
      if (_currentStep > 3) _currentStep = 3;

      // Se o status for 'verified', podemos pular a verificação se o app fechou depois dela
      if (data['status'] == 'verified' && _currentStep == 1) {
        _currentStep = 2; // Pula para senha
      }

      // Se estivermos no passo de contato mas ainda pendente, abrir o dialog de verificação automaticamente
      if (_currentStep == 1 && data['status'] == 'pending_verification') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showEmailVerificationDialog(_emailController.text);
        });
      }
    }

    // Logout preventivo: Apenas se for um cadastro totalmente limpo
    if (_createdUserId == null && widget.initialPendingData == null) {
      Supabase.instance.client.auth.signOut();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _academiaController.dispose();
    _cnpjController.dispose();
    _cpfController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar se plano foi selecionado no último step
    if (_selectedPlan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Por favor, selecione um plano para continuar.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    try {
      print('🚀 Iniciando fluxo de pagamento com plano: "$_selectedPlan"');

      // 1. Criar Usuário no Auth (Ou recuperar se já criado nesta sessão)
      String userId;
      final realEmail = _emailController.text.trim(); // Email verdadeiro
      final password = _passwordController.text;

      // Email temporário para não disparar confirmação no email real antes do pagamento
      final tempEmail =
          'pending_${DateTime.now().millisecondsSinceEpoch}@temp.spartan.app';

      if (_createdUserId != null) {
        print('♻️ Reutilizando usuário já criado: $_createdUserId');
        userId = _createdUserId!;
      } else {
        // Cria com email temporário
        final authResponse = await Supabase.instance.client.auth.signUp(
          email: tempEmail,
          password: password,
        );

        if (authResponse.user == null) {
          throw Exception('Falha ao criar conta de autenticação.');
        }

        userId = authResponse.user!.id;
        _createdUserId = userId;
        print('✅ Auth criado temporariamente ($tempEmail). ID: $userId');
      }

      // 2. Preparar Metadados para o Stripe (Isso será salvo no banco DEPOIS do pagamento via Webhook)
      final metadata = {
        'nome': _nameController.text.trim(),
        'telefone': _phoneController.text.trim(),
        'academia': _academiaController.text.trim(),
        'cnpj_academia': _cnpjMask.getUnmaskedText(),
        'cpf_responsavel': _cpfMask.getUnmaskedText(),
        'endereco': _addressController.text.trim(),
        'plano_selecionado': _selectedPlan,
        'user_id_auth': userId,
        'real_email_to_update':
            realEmail, // Passamos o email real aqui para o Webhook atualizar
      };

      // 3. Atualizar o Lead Tracking com o Plano Selecionado (Importante para repescagem)
      await _updateLeadTracking(
          step: 4, status: 'payment_pending', plan: _selectedPlan);

      // 4. Criar Sessão de Checkout
      final priceId = PaymentService.getPriceIdByName(_selectedPlan);

      print('🔄 Criando sessão de checkout...');
      final checkoutUrl = await PaymentService.createCheckoutSession(
        priceId: priceId,
        userId: userId,
        userEmail: realEmail, // Usa o email real para o Stripe (recibo)
        metadata: metadata,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
              'Timeout ao criar sessão de pagamento. Tente novamente.');
        },
      );

      print('💳 URL de Checkout gerada: $checkoutUrl');

      // 5. Redirecionar e Monitorar
      final uri = Uri.parse(checkoutUrl);
      print('🌐 Tentando abrir URL: $uri');

      if (await canLaunchUrl(uri)) {
        print('✅ URL pode ser aberta. Redirecionando...');
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (!launched) {
          throw Exception('Falha ao abrir navegador. Tente novamente.');
        }

        if (mounted) {
          // Inicia polling SILENCIOSO (sem diálogo de espera)
          _startSilentPolling(userId, realEmail);
        }
      } else {
        throw Exception('Não foi possível abrir a página de pagamento.');
      }
    } catch (e) {
      print('❌ Erro no registro: $e');
      if (mounted) {
        // Mensagens de erro amigáveis
        String msg = e.toString().replaceAll("Exception:", "");
        if (msg.contains('over_email_send_rate_limit')) {
          msg = 'Muitas tentativas. Aguarde 1 minuto e tente novamente.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro: $msg',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Exibe um dialog modal que monitora o pagamento
  // ignore: unused_element
  void _showWaitingPaymentDialog(String userId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                      height: 50,
                      width: 50,
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryGold, strokeWidth: 3)),
                  const SizedBox(height: 24),
                  Text(
                    'Pagamento em Andamento',
                    style: GoogleFonts.cinzel(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'A aba de pagamento foi aberta.\nContinue nela para finalizar.',
                    style:
                        TextStyle(color: AppTheme.secondaryText, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta tela avançará automaticamente\nassim que recebermos a confirmação.',
                    style: TextStyle(
                        color: AppTheme.primaryText,
                        fontWeight: FontWeight.bold,
                        height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Botão de Confirmação Manual
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Fecha dialog atual
                        _showRegistrationSuccessDialog(
                            _emailController.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'CONFIRMAR PAGAMENTO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Cancelar Espera',
                        style: TextStyle(color: Colors.grey)),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );

    // Inicia o loop de verificação
    bool confirmed = await _pollForUserCreation(userId);

    if (mounted) {
      Navigator.pop(context); // Fecha o loading

      if (confirmed) {
        // Sucesso Total! Passamos o email real para enviar confirmação agora
        final realEmail = _emailController.text.trim();
        _showRegistrationSuccessDialog(realEmail);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Tempo excedido. Verifique se o pagamento foi concluído.')));
      }
    }
  }

  /// Verifica periodicamente se o usuário foi criado no banco
  Future<bool> _pollForUserCreation(String userId) async {
    print('🔍 Polling via Edge Function iniciado para ID: $userId');
    // Tenta por 5 minutos (100 x 3s)
    for (int i = 0; i < 100; i++) {
      if (!mounted) return false;

      try {
        // Chamada à Edge Function que roda como Admin (ignora RLS)
        final response = await Supabase.instance.client.functions.invoke(
          'check-payment-status',
          body: {'userId': userId},
        );

        final data = response.data;

        if (data != null && data['confirmed'] == true) {
          print('✅ Polling Sucesso! Usuário encontrado via Function.');
          return true;
        }
      } catch (e) {
        print('⏳ Polling tentativa $i falhou: $e');
      }

      await Future.delayed(const Duration(seconds: 3));
    }
    return false;
  }

  void _startSilentPolling(String userId, String userEmail) async {
    print('🔍 Iniciando polling silencioso para User ID: $userId');
    _pollingCancelled = false; // Reset flag

    // Tenta por 5 minutos (100 x 3s)
    for (int i = 0; i < 100; i++) {
      if (!mounted || _pollingCancelled) {
        print('⏹️ Polling cancelado pelo usuário.');
        return;
      }

      try {
        // TENTATIVA 1: Edge Function (Normal)
        final response = await Supabase.instance.client.functions.invoke(
          'check-payment-status',
          body: {'userId': userId},
        );

        if (response.data != null && response.data['confirmed'] == true) {
          print('✅ Pagamento confirmado via Edge Function!');
          if (mounted) _showRegistrationSuccessDialog(userEmail);
          return;
        }
      } catch (e) {
        print(
            '⚠️ Edge Function falhou ou retornou 401. Tentando Fallback DB...');

        // TENTATIVA 2: Fallback Direto no Banco (Segurança contra 401/Invalid JWT)
        // Se o usuário foi criado em users_adm, o pagamento foi confirmado.
        try {
          final dbCheck = await Supabase.instance.client
              .from('users_adm')
              .select('id')
              .eq('id', userId)
              .maybeSingle();

          if (dbCheck != null) {
            print('✅ Pagamento confirmado via Fallback DB!');
            if (mounted) _showRegistrationSuccessDialog(userEmail);
            return;
          }
        } catch (dbError) {
          print('❌ Erro no fallback do banco: $dbError');
        }
      }

      await Future.delayed(const Duration(seconds: 4));
    }

    // Timeout
    print('⏰ Timeout: Polling encerrado sem confirmação.');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Tempo excedido. Verifique se o pagamento foi concluído.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showRegistrationSuccessDialog(String emailForConfirmation) {
    // Se houver algum diálogo aberto (ex: por um polling anterior), closes before
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9), // Verde claro sucesso
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Color(0xFF2E7D32), size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  'Cadastro Realizado!',
                  style: GoogleFonts.cinzel(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seu pagamento foi confirmado e sua conta de Administrador foi criada com sucesso.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, height: 1.5, color: AppTheme.secondaryText),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navegação direta e absoluta para o Login
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('IR PARA LOGIN',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _nextStep() async {
    // Validar formulário atual
    if (!_formKey.currentState!.validate()) return;

    // --- PASSO 1: DADOS CADASTRAIS (Index 0) ---
    if (_currentStep == 0) {
      if (!await _validateStep1Documents()) return;
      // Salvar rascunho em memória ou shared_prefs se quiser persistência local
      // Por enquanto, apenas avança para pedir o contato
      setState(() => _currentStep++);
      _animateToNextStep();
    }
    // --- PASSO 2: CONTATO (Index 1) ---
    else if (_currentStep == 1) {
      // Aqui acontece A MÁGICA do Funil + Verificação
      await _handleStep2ContactVerification();
    }
    // --- PASSO 3: SENHA (Index 2) ---
    else if (_currentStep == 2) {
      // Validar termos
      if (!_termsAccepted || !_privacyAccepted) {
        _showErrorSnackBar(
            'Você deve aceitar os Termos de Uso e Política de Privacidade para continuar.');
        return;
      }
      // Atualizar senha definitiva
      await _handleStep3PasswordUpdate();
    }
    // --- PASSO 4: PLANOS (Index 3) ---
    else if (_currentStep == 3) {
      // Finalização é feita pelo _handleRegister no botão de pagamento
    }
  }

  // Valida CPF e CNPJ (Logica extraída do antigo _nextStep)
  Future<bool> _validateStep1Documents() async {
    try {
      final validationResult =
          await DocumentValidationService.validateDocuments(
        cpf: _cpfMask.getUnmaskedText(),
        cnpj: _cnpjMask.getUnmaskedText(),
      );

      if (!mounted) return false;

      final cnpjData = validationResult['cnpj'];
      if (!cnpjData['valid']) {
        _showErrorSnackBar(cnpjData['message'] ?? 'CNPJ inválido');
        return false;
      }

      if (cnpjData['exists'] == false) {
        _showErrorSnackBar('CNPJ não encontrado na Receita Federal');
        return false;
      }

      if (cnpjData['active'] == false) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('CNPJ Inativo'),
            content: Text(
              'O CNPJ informado está inativo na Receita Federal.\n\nDetalhe: ${cnpjData['data']?['situacao']}\nDeseja continuar?',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Continuar')),
            ],
          ),
        );
        if (shouldContinue != true) return false;
      }

      final cpfData = validationResult['cpf'];
      if (!cpfData['valid']) {
        _showErrorSnackBar(cpfData['message'] ?? 'CPF inválido');
        return false;
      }

      return true;
    } catch (e) {
      _showErrorSnackBar('Erro ao validar documentos: $e');
      return false;
    }
  }

  // --- LÓGICA DO FUNIL (LEAD TRACKING) ---

  // Passo 2: Cria Auth Provisório, Salva Lead, Envia Email Manual
  Future<void> _handleStep2ContactVerification() async {
    final email = _emailController.text.trim();

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null && currentUser.email == email) {
      await _updateLeadTracking(step: 2, status: 'verified');
      setState(() => _currentStep++);
      _animateToNextStep();
      return;
    }

    final tempPassword =
        'Temp@${DateTime.now().millisecondsSinceEpoch}#Spartan';

    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()));

      // 1. Preparar URL de redirecionamento (Backup e Segurança)
      final origin = kIsWeb ? Uri.base.origin : 'https://spartanapp.com.br';
      final redirectUrl = '$origin/confirm.html';

      // 2. Criar o usuário no Auth
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: tempPassword,
        emailRedirectTo: redirectUrl,
      );

      if (authResponse.user != null) {
        _createdUserId = authResponse
            .user!.id; // CRITICAL: Salva o ID para reuso nos próximos passos
        // 3. Gerar Token Manual
        final customToken =
            (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
                .toString();

        // 4. Salvar dados (Protegido contra erros de coluna/banco)
        try {
          await Supabase.instance.client
              .from('email_verification_codes')
              .insert({
            'email': email,
            'code': customToken,
            'user_id': authResponse.user!.id,
            'expires_at':
                DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
            'verified': false,
          });

          await _saveLeadTrackingInitial(authResponse.user!.id);
        } catch (dbError) {
          print('⚠️ Alerta de Banco: $dbError');
        }

        // 5. Chamar Edge Function para enviar o email via Resend
        await _sendCustomVerificationEmail(email, customToken);

        if (!mounted) return;
        Navigator.pop(context); // Fecha loading (o círculo girando)

        // 6. FORÇAR O POPUP (Mesmo que o Supabase já tenha logado automaticamente)
        _showEmailVerificationDialog(email);
      }
    } on AuthApiException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Fecha loading

      if (e.statusCode == '429') {
        _showErrorSnackBar(
            'Muitas tentativas! Aguarde 1 minuto para enviar o e-mail novamente.');
      } else if (e.message.contains('already registered')) {
        _showErrorSnackBar('Este email já está cadastrado. Faça login.');
      } else {
        _showErrorSnackBar('Erro no Supabase: ${e.message}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackBar('Erro ao processar verificação: $e');
    }
  }

  // Função para chamar a Edge Function de Email
  Future<void> _sendCustomVerificationEmail(String email, String token) async {
    try {
      final origin = kIsWeb ? Uri.base.origin : 'https://spartanapp.com.br';
      final redirectUrl = '$origin/confirm.html';

      final response = await Supabase.instance.client.functions.invoke(
        'send-verification-email',
        body: {
          'email': email,
          'token': token,
          'redirect_url': redirectUrl,
        },
      );

      print('-------------------------------------------');
      print('🚀 RESPOSTA DA FUNÇÃO: ${response.data}');
      print('🚀 LINK DE ATIVAÇÃO EXTERNO: $redirectUrl?token=$token');
      print('-------------------------------------------');
    } catch (e) {
      print(
          '⚠️ Alerta: Erro ao chamar função de e-mail, mas o link está acima: $e');
      // Não rethrow para permitir que o popup abra mesmo se a função falhar
    }
  }

  // Passo 3: Atualizar Senha Definitiva
  Future<void> _handleStep3PasswordUpdate() async {
    final newPassword = _passwordController.text;

    // Verificar se senhas batem
    if (newPassword != _confirmPasswordController.text) {
      _showErrorSnackBar('As senhas não coincidem.');
      return;
    }

    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()));

      // 1. Atualizar senha no Auth
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // 2. Atualizar Lead Tracking (Step 3)
      await _updateLeadTracking(step: 3, status: 'password_set');

      if (!mounted) return;
      Navigator.pop(context); // Fecha loading

      // Avançar para Pagamento
      setState(() => _currentStep++);
      _animateToNextStep();
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('Erro ao definir senha: $e');
    }
  }

  // Salva o registro inicial no banco (INSERT)
  Future<void> _saveLeadTrackingInitial(String userId) async {
    final leadData = {
      'id': userId,
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'gym_name': _academiaController.text.trim(),
      'cnpj': _cnpjMask.getUnmaskedText(),
      'full_name': _nameController.text.trim(),
      'address_street': _addressController.text.trim(),
      'current_step': 1,
      'status': 'pending_verification'
    };

    try {
      await Supabase.instance.client
          .from('pending_registrations')
          .upsert(leadData);
    } catch (e) {
      print('⚠️ Alerta de Banco (Lead Tracking): $e');
    }
  }

  // Atualiza o registro existente (UPDATE)
  Future<void> _updateLeadTracking({
    required int step,
    required String status,
    String? plan,
  }) async {
    final userId =
        Supabase.instance.client.auth.currentUser?.id ?? _createdUserId;
    if (userId == null) return;

    final Map<String, dynamic> updateData = {
      'current_step': step,
      'status': status,
      // 'updated_at': DateTime.now().toIso8601String(), // Removido até que a coluna seja criada no SQL
    };

    if (plan != null) {
      updateData['plan'] = plan;
    }

    try {
      await Supabase.instance.client
          .from('pending_registrations')
          .update(updateData)
          .eq('id', userId);
      print('📊 Lead Tracking atualizado: Passo $step ($status)');
    } catch (e) {
      print('⚠️ Erro ao atualizar Lead Tracking: $e');
    }
  }

  void _showEmailVerificationDialog(String email) async {
    // Realtime para monitorar o status do lead no banco (Única fonte de verdade)
    RealtimeChannel? statusChannel;

    // OUVIR REALTIME: Se o status na tabela mudar para 'verified', avança
    statusChannel = Supabase.instance.client
        .channel('public:pending_registrations_check')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pending_registrations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _createdUserId, // Usar ID único é mais confiável que email
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'];
            print('🔔 Realtime: Status do Lead mudou para $newStatus');
            if (newStatus == 'verified' &&
                mounted &&
                Navigator.canPop(context)) {
              Navigator.pop(context, true);
            }
          },
        )
        .subscribe();

    // FALLBACK POLLING: Caso o Realtime falhe em algumas redes/navegadores
    bool isDialogStillOpen = true;
    _startEmailStatusPolling(email).then((_) {
      if (mounted && isDialogStillOpen && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    });

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_unread_rounded,
                  size: 60, color: AppTheme.primaryGold),
              const SizedBox(height: 24),
              Text(
                'Confirme seu Email',
                style: GoogleFonts.cinzel(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Enviamos um link de confirmação para:\n$email',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Clique no link enviado para continuar automaticamente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: Colors.black),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false); // Cancelou
                },
                child: const Text('Cancelar / Alterar Email',
                    style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );

    isDialogStillOpen = false;

    // Cancelar listeners ao sair do dialog
    if (statusChannel != null) {
      await Supabase.instance.client.removeChannel(statusChannel);
    }

    if (result == true && mounted) {
      // Sucesso confirmado
      await _updateLeadTracking(step: 2, status: 'verified');
      setState(() => _currentStep++);
      _animateToNextStep();
    }
  }

  Future<void> _startEmailStatusPolling(String email) async {
    int attempts = 0;
    while (attempts < 60 && mounted) {
      // 2 minutos de polling
      await Future.delayed(const Duration(seconds: 2));
      try {
        final response = await Supabase.instance.client
            .from('pending_registrations')
            .select('status')
            .eq('id', _createdUserId!)
            .maybeSingle();

        if (response != null && response['status'] == 'verified') {
          print('✅ Polling: Email verificado com sucesso!');
          return;
        }
      } catch (e) {
        print('⚠️ Erro no polling de email: $e');
      }
      attempts++;
    }
  }

  void _animateToNextStep() {
    _animationController.reset();
    _animationController.forward();
    _focusFirstField();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _animateToNextStep();
    }
  }

  // Focar no primeiro campo do step atual
  void _focusFirstField() {
    Future.delayed(const Duration(milliseconds: 100), () {
      switch (_currentStep) {
        case 0:
          _nameFocus.requestFocus();
          break;
        case 1:
          _phoneFocus.requestFocus();
          break;
        case 2:
          _passwordFocus.requestFocus();
          break;
        case 3:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.lightGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              // Progress indicator
              _buildProgressIndicator(),
              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Form(
                      key: _formKey,
                      child: _buildCurrentStep(),
                    ),
                  ),
                ),
              ),
              // Buttons
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            color: AppTheme.secondaryText,
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Cadastro de Administrador',
                  style: GoogleFonts.cinzel(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Passo ${_currentStep + 1} de 4',
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                gradient: isActive ? AppTheme.primaryGradient : null,
                color: isActive ? null : AppTheme.mediumGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle('Dados do Estabelecimento', Icons.store_rounded),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _academiaController,
          label: 'Nome da Academia',
          hint: 'Academia Spartan',
          icon: Icons.fitness_center_rounded,
          inputFormatters: [LengthLimitingTextInputFormatter(100)],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, insira o nome da academia';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _nameController,
          label: 'Nome Completo',
          hint: 'João Silva',
          icon: Icons.person_outline_rounded,
          focusNode: _nameFocus,
          inputFormatters: [LengthLimitingTextInputFormatter(100)],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, insira o nome completo';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _cnpjController,
          label: 'CNPJ',
          hint: '00.000.000/0000-00',
          icon: Icons.business_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [_cnpjMask],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, insira o CNPJ';
            }
            // Remove formatação para validar
            final unmasked = _cnpjMask.getUnmaskedText();
            if (unmasked.length != 14) {
              return 'CNPJ deve ter 14 dígitos';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _cpfController,
          label: 'CPF do Responsável',
          hint: '000.000.000-00',
          icon: Icons.badge_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [_cpfMask],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, insira o CPF';
            }
            // Remove formatação para validar
            final unmasked = _cpfMask.getUnmaskedText();
            if (unmasked.length != 11) {
              return 'CPF deve ter 11 dígitos';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _addressController,
          label: 'Endereço do Estabelecimento',
          hint: 'Rua, Número, Bairro, Cidade - UF',
          icon: Icons.location_on_outlined,
          maxLines: 2,
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, insira o endereço';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle('Dados de Contato', Icons.contact_phone_rounded),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _phoneController,
          label: 'Telefone',
          hint: '(00) 00000-0000',
          icon: Icons.phone_outlined,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, insira o telefone';
            }
            if (value.length < 10) {
              return 'Telefone inválido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'seu@email.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          inputFormatters: [LengthLimitingTextInputFormatter(100)],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, insira o email';
            }
            if (!value.contains('@')) {
              return 'Email inválido';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle('Dados de Acesso', Icons.lock_outline_rounded),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _passwordController,
          label: 'Senha',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          focusNode: _passwordFocus,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: AppTheme.secondaryText,
            ),
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, insira a senha';
            }
            if (value.length < 6) {
              return 'Senha deve ter no mínimo 6 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirmar Senha',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: AppTheme.secondaryText,
            ),
            onPressed: () {
              setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword);
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, confirme a senha';
            }
            if (value != _passwordController.text) {
              return 'As senhas não coincidem';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),

        // CHECKBOX TERMOS DE USO
        _buildLegalCheckbox(
          value: _termsAccepted,
          label: 'Li e concordo com os ',
          linkText: 'Termos de Uso',
          onChanged: (val) => setState(() => _termsAccepted = val ?? false),
          onTapLink: () => launchUrl(
            Uri.parse('/termos/'),
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_blank',
          ),
        ),

        // CHECKBOX POLÍTICA DE PRIVACIDADE
        _buildLegalCheckbox(
          value: _privacyAccepted,
          label: 'Li e concordo com a ',
          linkText: 'Política de Privacidade',
          onChanged: (val) => setState(() => _privacyAccepted = val ?? false),
          onTapLink: () => launchUrl(
            Uri.parse('/politicas/'),
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_blank',
          ),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            _buildStepTitle(
                'Quase lá! Vamos iniciar nossa jornada em instantes...',
                Icons.rocket_launch_rounded),
            const SizedBox(height: 8),
            Text(
              'Escolha um plano mensal:',
              style: GoogleFonts.lato(
                fontSize: 16,
                color: AppTheme.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            _buildPlanCard(
              id: 'Prata',
              name: 'Prata',
              price: '129,90',
              tag: 'VALIDAÇÃO',
              description: 'Ideal para academias de pequeno porte.',
              color: Colors.blueGrey,
              features: [
                'Módulos: Administrador, Nutricionista, Personal Trainer e Aluno.',
                'Dietas, Relatórios Físicos e Treinos.',
                'Monitoramento de Mensalidades, Controle Financeiro, Fluxo de Caixa e Relatórios Mensais e Anuais em PDF.',
                'Suporta até 200 alunos.',
              ],
            ),
            const SizedBox(height: 32),
            _buildPlanCard(
              id: 'Ouro',
              name: 'Ouro',
              price: '239,90',
              tag: 'MAIS ESCOLHIDO',
              description: 'Para quem já validou e precisa escalar.',
              color: const Color(0xFFD4AF37), // Dourado
              features: [
                'Módulos: Administrador, Nutricionista, Personal Trainer e Aluno.',
                'Dietas, Relatórios Físicos e Treinos.',
                'Monitoramento de Mensalidades, Controle Financeiro, Fluxo de Caixa e Relatórios Mensais e Anuais em PDF.',
                'Suporta até 500 alunos.',
                'Maior margem de lucro por aluno.',
                'Estrutura para crescimento forte.',
              ],
              isRecommended: true,
            ),
            const SizedBox(height: 24),
            _buildPlanCard(
              id: 'Platina',
              name: 'Platina',
              price: '349,90',
              tag: 'INFINITO',
              description: 'A liberdade absoluta. O céu é o limite.',
              color: const Color(0xFF00B8D4), // Cyan
              features: [
                'Módulos: Administrador, Nutricionista, Personal Trainer e Aluno.',
                'Dietas, Relatórios Físicos e Treinos Integrados.',
                'Monitoramento de Mensalidades, Controle Financeiro, Fluxo de Caixa e Relatórios Mensais e Anuais em PDF.',
                'Alunos ILIMITADOS.',
                'O céu é o limite! Aqui o lucro é exponencial.',
                'Estrutura para grandes empreendimentos.',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String name,
    required String price,
    required String tag,
    required String description,
    required Color color,
    required List<String> features,
    bool isRecommended = false,
  }) {
    final isSelected = _selectedPlan == id;

    // Fundo com opacidade dinâmica: 0.01 (1%) se selecionado, 0.02 (2%) se não selecionado
    // Reduzindo a intensidade visual conforme solicitado
    final cardBg =
        isSelected ? color.withOpacity(0.01) : color.withOpacity(0.02);

    return GestureDetector(
      onTap: () {
        setState(() => _selectedPlan = id);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              // Borda colorida
              border: Border.all(
                color: isSelected
                    ? color
                    : (isRecommended
                        ? color.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.2)),
                width: isSelected ? 2 : 1,
              ),
              // Sombra / LED
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 0),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: color.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: color,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 28,
                        width: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? color : Colors.transparent,
                          border: Border.all(
                            color: color,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Preço
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'R\$',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        price,
                        style: GoogleFonts.inter(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '/mês',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(height: 24),
                  Divider(color: color.withOpacity(0.1), height: 1),
                  const SizedBox(height: 24),

                  // Features
                  ...features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.bolt_rounded,
                                size: 18,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                feature,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          if (isRecommended)
            Positioned(
              top: -16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]),
                  child: Text(
                    'MAIS ESCOLHIDO',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGold.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: AppTheme.inputRadius,
        border: Border.all(
          color: AppTheme.borderGrey,
        ),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        maxLines: maxLines,
        style: const TextStyle(color: AppTheme.primaryText),
        cursorColor: AppTheme.primaryGold,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primaryGold),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: AppTheme.inputRadius,
            borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
          ),
          filled: false,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderGrey,
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: TextButton(
                    onPressed: _previousStep,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Voltar',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGold.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _currentStep == 3 ? _handleRegister : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentStep == 3 ? 'FINALIZAR CADASTRO' : 'CONTINUAR',
                      style: GoogleFonts.cinzel(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalCheckbox({
    required bool value,
    required String label,
    required String linkText,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onTapLink,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primaryGold,
          checkColor: Colors.white,
          side: BorderSide(color: AppTheme.primaryGold, width: 2),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: label,
              style: GoogleFonts.lato(
                fontSize: 14,
                color: AppTheme.primaryText,
              ),
              children: [
                WidgetSpan(
                  child: InkWell(
                    onTap: onTapLink,
                    child: Text(
                      linkText,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
