import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../config/app_theme.dart';
import 'login_screen.dart';

/// Tela de confirmação de email
/// Processa o token recebido do link do email
class EmailConfirmationScreen extends StatefulWidget {
  final String? token;

  const EmailConfirmationScreen({
    Key? key,
    this.token,
  }) : super(key: key);

  @override
  State<EmailConfirmationScreen> createState() =>
      _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  bool _isProcessing = true;
  bool _success = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _processConfirmation();
  }

  Future<void> _processConfirmation() async {
    print('🔄 EmailConfirmationScreen: Iniciando processamento...');

    // Aguarda um pouco para mostrar animação e deixar o SDK processar
    await Future.delayed(const Duration(milliseconds: 1500));

    // CHECK 1: O usuário já está logado? (SDK processou o link automaticamente)
    final currentUser = AuthService.currentUser;
    if (currentUser != null && currentUser.emailConfirmedAt != null) {
      print(
          '✅ Usuário já autenticado e confirmado pelo SDK! Verificando token pendente...');
      // Não retornamos aqui se tiver token para processar!
      // Precisamos garantir que os dados sejam inseridos no banco.
    }

    // CHECK 2: Se não logou, tentamos confirmar manualmente com o token
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() {
        _isProcessing = false;
        _success = false;
        _message = 'Link inválido ou já processado.';
      });
      return;
    }

    try {
      print('📞 Tentando confirmação manual com token...');
      final result = await AuthService.confirmRegistration(widget.token!);

      setState(() {
        _isProcessing = false;
        _success = result['success'] ?? false;
        _message = result['message'] ?? '';
      });

      if (_success) _redirectSuccess();
    } catch (e) {
      // Se der erro, pode ser que o SDK tenha confirmado no meio tempo
      final doubleCheckUser = AuthService.currentUser;
      if (doubleCheckUser != null && doubleCheckUser.emailConfirmedAt != null) {
        print('✅ Erro ignorado pois usuário foi confirmado em paralelo.');
        setState(() {
          _isProcessing = false;
          _success = true;
          _message = 'Email confirmado!';
        });
        _redirectSuccess();
      } else {
        setState(() {
          _isProcessing = false;
          _success = false;
          _message = 'Link expirado ou já utilizado.';
        });
      }
    }
  }

  void _redirectSuccess() async {
    print('🎉 Redirecionando em 3 segundos...');
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/splash_logo.png',
                    width: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.fitness_center_rounded,
                        size: 80,
                        color: AppTheme.primaryText,
                      );
                    },
                  ),
                  const SizedBox(height: 60),

                  // Conteúdo
                  if (_isProcessing) ...[
                    // Processando
                    const CircularProgressIndicator(
                      color: AppTheme.primaryGold,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Confirmando seu cadastro...',
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aguarde um momento',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: AppTheme.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    // Resultado
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _success
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _success ? Icons.check_circle : Icons.error,
                        size: 60,
                        color: _success ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _success ? 'Cadastro Confirmado!' : 'Erro na Confirmação',
                      style: GoogleFonts.lato(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _message,
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: AppTheme.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Botão
                    if (_success)
                      Text(
                        'Redirecionando para o login...',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: AppTheme.hintText,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Voltar ao Login',
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
