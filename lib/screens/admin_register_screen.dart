import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/document_validation_service.dart';
import '../config/app_theme.dart';
import 'login_screen.dart';

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
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Variáveis de Aceite Legal
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _isLoading = false;

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
  final _phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

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

    // Lógica de Resumo de Cadastro Corrigida
    if (widget.initialPendingData != null) {
      final data = widget.initialPendingData!;
      _emailController.text = data['email'] ?? '';

      // Smart Fix: Se detectarmos que os dados vieram trocados do banco (nome na academia ou vice-versa)
      // Aqui garantimos que no formulário o usuário veja as coisas nos lugares certos
      _nameController.text = data['full_name'] ?? '';
      _academiaController.text = data['gym_name'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _cnpjController.text = data['cnpj'] ?? '';
      _addressController.text = data['address_street'] ?? '';
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
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // 1. Validar Formulário e Termos
    if (!_formKey.currentState!.validate()) return;

    if (!_termsAccepted || !_privacyAccepted) {
      _showErrorSnackBar(
          'Você deve aceitar os Termos de Uso e Política de Privacidade para continuar.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      print('🚀 Iniciando Cadastro Definitivo para: $email');

      // 2. Verificar se e-mail já existe (Proativo)
      final existingCheck = await Supabase.instance.client
          .from('users_adm')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (existingCheck != null) {
        _showUserAlreadyExistsDialog();
        return;
      }

      // 3. Criar Conta no Auth (SignUp Real com Metadados para o Trigger)
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'role': 'admin',
          'name': _nameController.text.trim(),
          'academia': _academiaController.text.trim(),
          'phone': _phoneMask.getUnmaskedText(),
          'cnpj_academia': _cnpjMask.getUnmaskedText(),
        },
      );

      final user = response.user;
      if (user == null) throw Exception('Falha ao criar conta.');

      // 3. Salvar na Tabela de Pendentes (Segunda via de segurança)
      await Supabase.instance.client.from('pending_registrations').upsert({
        'id': user.id,
        'email': email,
        'full_name':
            _nameController.text.trim(), // COLUNA 'full_name' = NOME DO ADMIN
        'gym_name': _academiaController.text
            .trim(), // COLUNA 'gym_name' = NOME DA ACADEMIA
        'phone': _phoneMask.getUnmaskedText(),
        'cnpj': _cnpjMask.getUnmaskedText(),
        'cpf': _cpfMask.getUnmaskedText(),
        'address_street': _addressController.text.trim(),
        'status': 'verified',
        'current_step': 2,
      });

      print('✅ Registro pendente salvo. Redirecionando para Login.');

      if (mounted) {
        // 4. Mostrar Diálogo de Sucesso e ir para Login
        _showRegistrationSuccessDialog(email);
      }
    } catch (e) {
      print('❌ Erro no Registro: $e');
      String msg = e.toString();

      if (msg.contains('User already registered') ||
          msg.contains('identificator_already_exists')) {
        _showUserAlreadyExistsDialog();
      } else {
        _showErrorSnackBar('Erro no cadastro: $msg');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUserAlreadyExistsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'E-mail já cadastrado!',
          style: GoogleFonts.cinzel(
              color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Identificamos que você já possui uma conta no Spartan App.\n\nPor favor, faça login para continuar e configurar sua assinatura.',
          textAlign: TextAlign.center,
          style: GoogleFonts.lato(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('IR PARA LOGIN',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
                  'Sua conta foi criada com sucesso e o login está autorizado.',
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

      setState(() => _currentStep++);
      _animateToNextStep();
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
    // Atraso um pouco maior para garantir que a animação da PageView terminou
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      switch (_currentStep) {
        case 0:
          _nameFocus.requestFocus();
          break;
        case 1:
          _emailFocus.requestFocus();
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
                  'Passo ${_currentStep + 1} de 2',
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
        children: List.generate(2, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 1 ? 8 : 0),
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
        return _buildStep1(); // Dados Gerais
      case 1:
        return _buildStep2(); // Acesso
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle('Dados da Academia e Responsável', Icons.store_rounded),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _nameController,
          label: 'Nome Completo',
          hint: 'João Silva',
          icon: Icons.person_outline_rounded,
          focusNode: _nameFocus,
          textCapitalization: TextCapitalization.words, // AUTO MAIÚSCULA
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
          controller: _phoneController,
          label: 'Telefone',
          hint: '(00) 00000-0000',
          icon: Icons.phone_outlined,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            _phoneMask,
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, insira o telefone';
            }
            if (_phoneMask.getUnmaskedText().length < 10) {
              return 'Telefone inválido';
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
            final unmasked = _cpfMask.getUnmaskedText();
            if (unmasked.length != 11) {
              return 'CPF deve ter 11 dígitos';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _academiaController,
          label: 'Nome da Academia',
          hint: 'Academia Spartan',
          icon: Icons.fitness_center_rounded,
          textCapitalization: TextCapitalization.words, // AUTO MAIÚSCULA
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
            final unmasked = _cnpjMask.getUnmaskedText();
            if (unmasked.length != 14) {
              return 'CNPJ deve ter 14 dígitos';
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
        _buildStepTitle('Dados de Acesso', Icons.lock_outline_rounded),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'seu@email.com',
          icon: Icons.email_outlined,
          focusNode: _emailFocus,
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
        const SizedBox(height: 16),
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

  // Métodos auxiliares de UI abaixo.

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
    TextCapitalization textCapitalization = TextCapitalization.none,
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
        textCapitalization: textCapitalization,
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
                    onPressed: _currentStep == 1 ? _handleRegister : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _currentStep == 1
                                ? 'FINALIZAR CADASTRO'
                                : 'CONTINUAR',
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
