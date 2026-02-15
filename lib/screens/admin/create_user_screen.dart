import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/user_role.dart';
import '../../services/user_service.dart';
import '../../config/app_theme.dart';
import '../../widgets/subscription_check.dart';
import 'subscription_screen.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  static const String _landingUrl = 'https://spartanapp.com.br/landing.html';
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _initialPaymentController = TextEditingController(); // Novo controller

  DateTime? _selectedBirthDate;
  UserRole _selectedRole = UserRole.student;
  int? _selectedPaymentDay; // Dia de vencimento
  bool _isPaidCurrentMonth = false; // Pagamento inicial
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateController.dispose();
    _initialPaymentController.dispose(); // Dispose novo controller
    super.dispose();
  }

  String _formatNameTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    // 0. VERIFICAR SE ASSINATURA ESTÁ ATIVA
    final canProceed = await checkSubscription(context);
    if (!canProceed) return; // Bloqueado - popup já exibido

    // 1. CHECAGEM PRÉVIA DE LIMITE (Antes de tentar cadastrar)
    if (_selectedRole == UserRole.student) {
      final verificationStatus = await UserService.checkPlanLimitStatus();
      // Se JÁ ESTÁ no limite (ex: 200/200) e tenta cadastrar mais um
      if (verificationStatus['isAtLimit'] == true) {
        _showUpgradeDialog();
        return; // Interrompe o processo aqui
      }
    }

    setState(() => _isLoading = true);

    try {
      String finalEmail = _emailController.text.trim();
      String finalPassword = _passwordController.text;

      // Lógica para campos opcionais de Aluno (Gerar dados provisórios)
      if (_selectedRole == UserRole.student) {
        if (finalEmail.isEmpty) {
          // Gerar email temporário único
          final uniqueId = DateTime.now().millisecondsSinceEpoch;
          finalEmail = 'aluno.$uniqueId@spartan.system';
        }
        if (finalPassword.isEmpty) {
          // Gerar senha forte automática
          finalPassword = 'Spt@${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      final result = await UserService.createUserByAdmin(
        name: _formatNameTitleCase(_nameController.text),
        email: finalEmail,
        password: finalPassword,
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        birthDate: _selectedBirthDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedBirthDate!)
            : null,
        paymentDueDay:
            _selectedRole == UserRole.student ? _selectedPaymentDay : null,
        isPaidCurrentMonth:
            _selectedRole == UserRole.student ? _isPaidCurrentMonth : false,
        initialPaymentAmount:
            _selectedRole == UserRole.student && _isPaidCurrentMonth
                ? double.tryParse(
                    _initialPaymentController.text.replaceAll(',', '.'))
                : null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        if (!mounted) return;

        // 2. CHECAGEM PÓS-CADASTRO (Para exibir o aviso de "Limite Atingido")
        if (_selectedRole == UserRole.student) {
          try {
            final limitStatus = await UserService.checkPlanLimitStatus();
            // Se atingiu o limite AGORA (ex: virou 200/200 com este cadastro)
            if (limitStatus['isAtLimit'] == true && mounted) {
              Navigator.pop(context, true);
              _showLimitReachedSuccessDialog(limitStatus['plan']);
              return;
            }
          } catch (e) {
            print('Erro check silencioso: $e');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Usuário cadastrado com sucesso!',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        // Fallback: Se o backend retornar erro de limite (segurança dupla)
        final message = result['message']?.toString() ?? '';

        if (message.contains('Limite de alunos atingido') ||
            message.contains('users_alunos_check')) {
          _showUpgradeDialog();
        } else if (message.contains('unique constraint') ||
            message.contains('duplicate key')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Este e-mail já está cadastrado no sistema.',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Erro ao cadastrar usuário',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString();
        if (message.contains('Limite de alunos atingido')) {
          _showUpgradeDialog();
        } else if (message.contains('unique constraint') ||
            message.contains('duplicate key')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Este e-mail já está cadastrado no sistema.',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erro inesperado: ${e.toString()}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              // Borda dourada sutil
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.3),
                blurRadius: 0,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone de Bloqueio/Crescimento
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFF9E6), // Amarelo bem claro
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded, // Mudado para foguete
                  size: 56,
                  color: Color(0xFFFFD700), // Dourado
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Hora de Crescer! 🚀',
                style: GoogleFonts.cinzel(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                'Incrível! Sua academia atingiu o limite máximo do plano atual.',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: const Color(0xFF666666),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'O próximo cadastro só será liberado após o upgrade.',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFCC3300), // Vermelho aviso elegante
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Fecha Dialog
                    // Navega para Subscription
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SubscriptionScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700), // Dourado
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFFFFD700).withOpacity(0.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'DESBLOQUEAR CRESCIMENTO',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF999999),
                ),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLimitReachedSuccessDialog(String plan) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone Celebrativo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8F5E9), // Verde bem claro
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 56,
                  color: Color(0xFFFFD700), // Dourado
                ),
              ),
              const SizedBox(height: 24),

              // Título (Foguete na mesma linha)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'PARABÉNS! VOCÊ CRESCEU! 🚀',
                  style: GoogleFonts.cinzel(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // CARD 1: Informação do Plano
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5), // Cinza bem claro
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      color: const Color(0xFF666666),
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(
                          text:
                              'Você acaba de preencher a última vaga do seu plano '),
                      TextSpan(
                        text: plan.toUpperCase(),
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.w900,
                          color: Colors.black, // Destaque
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12), // Espaçamento clean

              // CARD 2: Necessidade de Upgrade
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Para cadastrar mais usuários, é necessário fazer o upgrade do seu plano mensal.',
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    color: Colors.black, // Texto Preto conforme pedido
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 12), // Espaçamento clean

              // CARD 3: Mensagem de Motivação (Verde Sucesso)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9), // Verde bem clarinho
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF2A9D8F).withOpacity(0.3)),
                ),
                child: Text(
                  'Atingir o limite é o maior sinal de que seu negócio é um sucesso absoluto!',
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    color: const Color(0xFF2A9D8F),
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Fecha Dialog
                    Navigator.pop(context, true); // Fecha Tela de Cadastro

                    // Navega para Subscription
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SubscriptionScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFFFFD700).withOpacity(0.4),
                  ),
                  child: const Text(
                    'QUERO CONTINUAR CRESCENDO', // Botão mais persuasivo
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF999999),
                ),
                child: const Text('Fechar e ver lista de alunos'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.nutritionist:
        return 'Nutricionista';
      case UserRole.trainer:
        return 'Personal Trainer';
      case UserRole.student:
        return 'Aluno';
      case UserRole.admin:
        return 'Administrador';
      case UserRole.visitor:
        return 'Visitante';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.nutritionist:
        return const Color(0xFF2A9D8F);
      case UserRole.trainer:
        return AppTheme.primaryRed;
      case UserRole.student:
        return const Color(0xFF457B9D);
      case UserRole.admin:
        return const Color(0xFF1A1A1A);
      case UserRole.visitor:
        return AppTheme.primaryGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.secondaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Cadastrar Usuário',
          style: GoogleFonts.cinzel(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Seleção de tipo de usuário
                Text(
                  'TIPO DE USUÁRIO',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryText,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Cards de seleção de role
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleCard(
                        UserRole.nutritionist,
                        Icons.restaurant_menu_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRoleCard(
                        UserRole.trainer,
                        Icons.fitness_center_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRoleCard(
                  UserRole.student,
                  Icons.person_rounded,
                ),

                const SizedBox(height: 30),

                Text(
                  'DADOS DO USUÁRIO',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryText,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                // Nome
                _buildTextField(
                  controller: _nameController,
                  label: 'Nome Completo',
                  hint: 'João Silva',
                  icon: Icons.person_outline_rounded,
                  textCapitalization:
                      TextCapitalization.words, // AUTO MAIÚSCULA
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira o nome completo';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Email
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'usuario@email.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  validator: (value) {
                    if (_selectedRole == UserRole.student &&
                        (value == null || value.isEmpty)) {
                      return null; // Opcional para alunos
                    }
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

                // Telefone
                _buildTextField(
                  controller: _phoneController,
                  label: 'Telefone',
                  hint: '(00) 00000-0000',
                  icon: Icons.phone_outlined,
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

                const SizedBox(height: 16),

                // Data de Nascimento
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 18)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      locale: const Locale('pt', 'BR'),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: _getRoleColor(_selectedRole),
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() {
                        _selectedBirthDate = date;
                        _birthDateController.text =
                            DateFormat('dd/MM/yyyy').format(date);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: _buildTextField(
                      controller: _birthDateController,
                      label: 'Data de Nascimento',
                      hint: 'DD/MM/AAAA',
                      icon: Icons.calendar_today_rounded,
                      validator: (value) {
                        return null; // Opcional
                      },
                    ),
                  ),
                ),

                // Dia de Vencimento (Apenas para Alunos)
                if (_selectedRole == UserRole.student) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey,
                      borderRadius: AppTheme.inputRadius,
                      border: Border.all(color: AppTheme.borderGrey),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<int>(
                        value: _selectedPaymentDay,
                        decoration: const InputDecoration(
                          labelText: 'Dia de Vencimento',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.date_range_rounded,
                              color: Color(0xFF1A1A1A)),
                        ),
                        hint: const Text('Selecione o dia'),
                        items: List.generate(31, (index) => index + 1)
                            .map((day) => DropdownMenuItem(
                                  value: day,
                                  child: Text('Dia $day'),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedPaymentDay = value),
                        validator: (value) {
                          if (_selectedRole == UserRole.student &&
                              value == null) {
                            return 'Selecione o dia de vencimento';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Switch Pagamento Inicial
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey,
                      borderRadius: AppTheme.inputRadius,
                      border: Border.all(color: AppTheme.borderGrey),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        'Mensalidade deste mês Paga?',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      subtitle: Text(
                        'Se ativado, o aluno já entra como "Pago"',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                      value: _isPaidCurrentMonth,
                      activeColor: Colors.green,
                      onChanged: (val) =>
                          setState(() => _isPaidCurrentMonth = val),
                    ),
                  ),

                  // Campo de Valor (Se pago)
                  if (_isPaidCurrentMonth) ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _initialPaymentController,
                      label: 'Valor Pago (R\$)',
                      hint: '0.00',
                      icon: Icons.attach_money_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (!_isPaidCurrentMonth) return null;
                        if (value == null || value.isEmpty) {
                          return 'Informe o valor pago';
                        }
                        return null;
                      },
                    ),
                  ],
                ],

                const SizedBox(height: 16),

                // Senha
                _buildTextField(
                  controller: _passwordController,
                  label: 'Senha',
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
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
                    if (_selectedRole == UserRole.student &&
                        (value == null || value.isEmpty)) {
                      return null; // Opcional para alunos
                    }
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

                // Confirmar Senha
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
                      setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                  validator: (value) {
                    if (_selectedRole == UserRole.student &&
                        (_passwordController.text.isEmpty)) {
                      return null; // Se senha vazia (aluno), confirmação também opcional
                    }
                    if (_selectedRole == UserRole.student &&
                        (value == null || value.isEmpty)) {
                      // Se senha preenchida, mas confirmação vazia -> ERRO (A menos que senha também vazia)
                      // Correção lógica: Se senha principal preenchida, confirmação é obrigatória.
                      // Se senha principal vazia, confirmação opcional.
                      return null;
                    }

                    if (value == null || value.isEmpty) {
                      return 'Por favor, confirme a senha';
                    }
                    if (value != _passwordController.text) {
                      return 'As senhas não coincidem';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                // Seção QR Code e Download (Sempre visível)

                // Seção QR Code e Download (Sempre visível)
                RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderGrey),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Sistema Pronto para Uso!',
                          style: GoogleFonts.cinzel(
                            color: AppTheme.primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: QrImageView(
                            data: _landingUrl,
                            version: QrVersions.auto,
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                            size: 250.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGrey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  _landingUrl,
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 12,
                                    color: AppTheme.secondaryText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 20),
                                color: AppTheme.primaryText,
                                onPressed: () {
                                  Clipboard.setData(
                                      const ClipboardData(text: _landingUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Link copiado para a área de transferência!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Botão Cadastrar
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: AppTheme.buttonRadius,
                    boxShadow: [
                      const BoxShadow(
                        color: Color(0xFF1A1A1A),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? () {} : _handleCreate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.buttonRadius,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Cadastrar',
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(UserRole role, IconData icon) {
    final isSelected = _selectedRole == role;
    final color = _getRoleColor(role);

    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: AppTheme.cardRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppTheme.white,
          borderRadius: AppTheme.cardRadius,
          border: Border.all(
            color: isSelected ? color : AppTheme.borderGrey,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? color : AppTheme.secondaryText,
            ),
            const SizedBox(height: 8),
            Text(
              _getRoleName(role),
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppTheme.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
    TextCapitalization textCapitalization = TextCapitalization.sentences,
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
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        maxLines: maxLines,
        style: const TextStyle(color: AppTheme.primaryText),
        cursorColor: const Color(0xFF1A1A1A),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF1A1A1A)),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: AppTheme.inputRadius,
            borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 2),
          ),
          filled: false,
        ),
        validator: validator,
      ),
    );
  }
}
