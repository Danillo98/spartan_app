import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/financial_service.dart';
import '../config/app_theme.dart';
import 'admin_register_screen.dart';
import 'forgot_password_screen.dart';
import 'admin/admin_dashboard.dart';
import 'nutritionist/nutritionist_dashboard.dart';
import 'trainer/trainer_dashboard.dart';
import 'student/student_dashboard.dart';

class RoleLoginScreen extends StatefulWidget {
  final UserRole role;
  final String roleTitle;

  const RoleLoginScreen({
    super.key,
    required this.role,
    required this.roleTitle,
  });

  @override
  State<RoleLoginScreen> createState() => _RoleLoginScreenState();
}

class _RoleLoginScreenState extends State<RoleLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Verificar se o role do usuário corresponde ao esperado
        final userData = result['user'] as Map<String, dynamic>;
        final userRoleString = userData['role'] as String;
        final userRole = UserRole.values.firstWhere(
          (role) => role.toString().split('.').last == userRoleString,
          orElse: () => UserRole.student,
        );

        if (userRole != widget.role) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Este login é exclusivo para ${widget.roleTitle}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          await AuthService.signOut();
          setState(() => _isLoading = false);
          return;
        }

        // VERIFICAÇÃO DE INADIMPLÊNCIA (Apenas para Alunos)
        if (userRole == UserRole.student) {
          final studentId = userData['id'];
          final idAcademia = userData['id_academia'];
          final paymentDueDay = userData['payment_due_day'];

          if (idAcademia != null) {
            // Chamada segura para verificar pendência
            bool isOverdue = false;
            try {
              isOverdue = await FinancialService.isStudentOverdue(
                studentId: studentId,
                idAcademia: idAcademia,
                paymentDueDay: paymentDueDay is int
                    ? paymentDueDay
                    : int.tryParse(paymentDueDay.toString()),
              );
            } catch (e) {
              print('Erro ao verificar status financeiro: $e');
              // Em caso de erro na verificação, por segurança, não bloqueia (ou bloqueia? Geralmente melhor não bloquear por erro técnico)
            }

            if (isOverdue) {
              await AuthService.signOut();
              if (mounted) {
                setState(() => _isLoading = false);

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            color: AppTheme.accentRed, size: 28),
                        const SizedBox(width: 10),
                        const Text('Acesso Bloqueado'),
                      ],
                    ),
                    content: const Text(
                      'Sua mensalidade está vencida.\n\nPor favor, realize o pagamento para liberar seu acesso ao aplicativo.',
                      style: TextStyle(fontSize: 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'ENTENDI',
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return;
            }
          }
        }

        Widget dashboard;
        switch (widget.role) {
          case UserRole.admin:
            dashboard = const AdminDashboard();
            break;
          case UserRole.nutritionist:
            dashboard = const NutritionistDashboard();
            break;
          case UserRole.trainer:
            dashboard = const TrainerDashboard();
            break;
          case UserRole.student:
            dashboard = const StudentDashboard();
            break;
        }

        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => dashboard,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Erro ao fazer login',
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

  void _navigateToRegister() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AdminRegisterScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Color _getRoleColor() {
    switch (widget.role) {
      case UserRole.admin:
        return const Color(0xFF1A1A1A);
      case UserRole.nutritionist:
        return const Color(0xFF2A9D8F);
      case UserRole.trainer:
        return AppTheme.primaryRed;
      case UserRole.student:
        return const Color(0xFF457B9D);
    }
  }

  IconData _getRoleIcon() {
    switch (widget.role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.nutritionist:
        return Icons.restaurant_menu_rounded;
      case UserRole.trainer:
        return Icons.fitness_center_rounded;
      case UserRole.student:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor();

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.lightGradient, // Fundo claro suave
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Botão voltar
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded),
                            color: AppTheme.secondaryText,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Ícone do perfil
                        Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.white,
                              border: Border.all(
                                color: roleColor.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: roleColor.withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              _getRoleIcon(),
                              size: 50,
                              color: roleColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Título
                        Text(
                          widget.roleTitle,
                          style: GoogleFonts.cinzel(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Faça login para continuar',
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: AppTheme.secondaryText,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 40),

                        // Email
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'seu@email.com',
                          icon: Icons.email_outlined,
                          roleColor: roleColor,
                          keyboardType: TextInputType.emailAddress,
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

                        const SizedBox(height: 20),

                        // Senha
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Senha',
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          roleColor: roleColor,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppTheme.secondaryText,
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, insira a senha';
                            }
                            return null;
                          },
                        ),

                        // Esqueci minha senha (apenas para admin)
                        if (widget.role == UserRole.admin) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Esqueci minha senha',
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  color: roleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),

                        // Botão Login
                        _buildLoginButton(roleColor),

                        // Botão de criar conta (apenas para admin)
                        if (widget.role == UserRole.admin) ...[
                          const SizedBox(height: 24),
                          _buildRegisterButton(roleColor),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color roleColor,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
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
        obscureText: obscureText,
        style: const TextStyle(color: AppTheme.primaryText),
        cursorColor: roleColor,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: roleColor),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: AppTheme.inputRadius,
            borderSide: BorderSide(color: roleColor, width: 2),
          ),
          filled: false,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildLoginButton(Color roleColor) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [roleColor, roleColor.withOpacity(0.8)],
        ),
        borderRadius: AppTheme.buttonRadius,
        boxShadow: [
          BoxShadow(
            color: roleColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
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
                'ENTRAR',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.white, // Texto branco no botão colorido
                ),
              ),
      ),
    );
  }

  Widget _buildRegisterButton(Color roleColor) {
    return TextButton(
      onPressed: _navigateToRegister,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.lato(
            fontSize: 14,
            color: AppTheme.secondaryText,
          ),
          children: [
            const TextSpan(text: 'Não tem uma conta? '),
            TextSpan(
              text: 'Cadastre-se',
              style: GoogleFonts.lato(
                color: roleColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
