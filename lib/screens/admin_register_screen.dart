import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../services/auth_service.dart';
import '../services/document_validation_service.dart';
import '../config/app_theme.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

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

  String _selectedPlan = ''; // Plano selecionado

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

    setState(() => _isLoading = true);

    try {
      // Cadastrar admin (envia email de confirmação automaticamente)
      final result = await AuthService.registerAdmin(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        cnpjAcademia: _cnpjMask.getUnmaskedText(), // CNPJ sem máscara
        academia: _academiaController.text.trim(), // Nome da Academia
        cnpj: '', // CNPJ Pessoal (opcional, não está no form)
        cpf: _cpfMask.getUnmaskedText(), // CPF sem máscara
        address: _addressController.text.trim(),
        plan: _selectedPlan, // Plano selecionado
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Mostrar mensagem de sucesso
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.email, color: AppTheme.success, size: 28),
                const SizedBox(width: 12),
                const Text('Verifique seu Email'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enviamos um link de confirmação para:',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  result['email'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Clique no link do email para ativar sua conta',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Fechar dialog
                  Navigator.of(context).pop(); // Voltar para login
                },
                child: const Text('OK, Entendi'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Erro ao cadastrar',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro inesperado: ${e.toString()}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _nextStep() async {
    // Validar formulário atual
    if (!_formKey.currentState!.validate()) return;

    // Se estiver no Step 1, validar CPF e CNPJ antes de avançar
    if (_currentStep == 0) {
      setState(() => _isLoading = true);

      try {
        // Validar documentos com API
        final validationResult =
            await DocumentValidationService.validateDocuments(
          cpf: _cpfMask.getUnmaskedText(),
          cnpj: _cnpjMask.getUnmaskedText(),
        );

        if (!mounted) return;

        // Verificar se CNPJ é válido
        final cnpjData = validationResult['cnpj'];
        if (!cnpjData['valid']) {
          setState(() => _isLoading = false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                cnpjData['message'] ?? 'CNPJ inválido',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        }

        // Verificar se CNPJ existe
        if (cnpjData['exists'] == false) {
          setState(() => _isLoading = false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'CNPJ não encontrado na Receita Federal',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        }

        // Verificar se CNPJ está ativo
        if (cnpjData['active'] == false) {
          setState(() => _isLoading = false);

          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('CNPJ Inativo'),
              content: Text(
                'O CNPJ informado está inativo na Receita Federal.\n\n'
                'Situação: ${cnpjData['data']?['situacao'] ?? 'Não ativa'}\n\n'
                'Deseja continuar mesmo assim?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                  ),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          );

          if (shouldContinue != true) {
            setState(() => _isLoading = false);
            return;
          }
        }

        // Mostrar informações do CNPJ validado
        if (cnpjData['data'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'CNPJ validado: ${cnpjData['data']['razao_social'] ?? 'Empresa'}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }

        // Validação de CPF (apenas matemática, pois API não verifica existência)
        final cpfData = validationResult['cpf'];
        if (!cpfData['valid']) {
          setState(() => _isLoading = false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                cpfData['message'] ?? 'CPF inválido',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        }

        setState(() => _isLoading = false);
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erro ao validar documentos: ${e.toString()}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }
    }

    // Avançar para próximo step
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _animationController.reset();
      _animationController.forward();

      // Focar no primeiro campo do próximo step
      _focusFirstField();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _animationController.reset();
      _animationController.forward();

      // Focar no primeiro campo do step anterior
      _focusFirstField();
    }
  }

  // Focar no primeiro campo do step atual
  void _focusFirstField() {
    // Aguardar a animação terminar antes de focar
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
          // Sem foco automático no step 4
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
                'Suporta até 250 alunos.',
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
        Text(
          title,
          style: GoogleFonts.lato(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryText,
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
                    onPressed: _isLoading ? null : _previousStep,
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
                    onPressed: _isLoading
                        ? null
                        : (_currentStep == 3 ? _handleRegister : _nextStep),
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _currentStep == 3
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
}
