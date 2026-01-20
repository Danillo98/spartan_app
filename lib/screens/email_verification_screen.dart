import 'package:flutter/material.dart';

/// NOTA: Esta tela não é mais utilizada no fluxo atual.
/// O sistema agora usa confirmação por LINK no email,
/// não por código de verificação.
///
/// Esta tela foi mantida apenas para compatibilidade,
/// mas não será acessada no fluxo normal.

class EmailVerificationScreen extends StatelessWidget {
  final String email;
  final Map<String, dynamic>? pendingData;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.pendingData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Verificação de Email'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.email_outlined,
                size: 100,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 32),
              Text(
                'Verificação por Link',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Esta tela não é mais utilizada.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'O sistema agora usa confirmação por link enviado no email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
