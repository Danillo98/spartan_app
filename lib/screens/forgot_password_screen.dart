import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../services/auth_service.dart';
import '../config/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
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
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      // 1. Verificar se é Admin (para economizar e-mails)
      // Tenta buscar na tabela de admins
      final adminData = await Supabase.instance.client
          .from('users_adm')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (adminData != null) {
        // É Admin -> Pode enviar e-mail
        await AuthService.sendPasswordResetEmail(email);

        if (!mounted) return;

        // Mostrar mensagem de sucesso (Link Enviado)
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 32),
                const SizedBox(width: 12),
                Text(
                  'Email Enviado!',
                  style: GoogleFonts.cinzel(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enviamos um link de recuperação para:',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryText,
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
                      Icon(Icons.info_outline,
                          color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verifique sua caixa de entrada e spam.',
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            color: Colors.blue[900],
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
                  Navigator.of(context).pop(); // Fecha dialog
                  Navigator.of(context).pop(); // Volta para login
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // NÃO é Admin (ou não encontrado) -> Bloqueia e avisa
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.lock_outline, color: AppTheme.primaryText, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Atenção',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Entre em contato com a gestão da academia para redefinir a senha!',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ENTENDI'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('Erro no reset: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const roleColor = Color(0xFF1A1A1A); // Cor do admin

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.lightGradient,
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

                        // Ícone
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
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              size: 50,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Título
                        Text(
                          'Recuperar Senha',
                          style: GoogleFonts.cinzel(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Digite seu email para receber o link de recuperação',
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: AppTheme.secondaryText,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 40),

                        // Campo de Email
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.lightGrey,
                            borderRadius: AppTheme.inputRadius,
                            border: Border.all(
                              color: AppTheme.borderGrey,
                            ),
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppTheme.primaryText),
                            cursorColor: roleColor,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'seu@email.com',
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Color(0xFF1A1A1A),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppTheme.inputRadius,
                                borderSide: const BorderSide(
                                  color: Color(0xFF1A1A1A),
                                  width: 2,
                                ),
                              ),
                              filled: false,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Digite seu email';
                              }
                              if (!value.contains('@')) {
                                return 'Digite um email válido';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Botão Enviar
                        Container(
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
                            onPressed: _isLoading ? null : _sendResetEmail,
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
                                    'ENVIAR LINK',
                                    style: GoogleFonts.lato(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Botão Voltar
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Voltar para Login',
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ),

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
}
