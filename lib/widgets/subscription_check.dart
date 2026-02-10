import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/admin/subscription_screen.dart';
import '../screens/login_screen.dart';

/// Mixin para verificar assinatura antes de ações críticas
/// Use em telas que precisam verificar status antes de operações importantes
mixin SubscriptionCheckMixin<T extends StatefulWidget> on State<T> {
  /// Verifica se a assinatura está ativa antes de uma ação
  /// Retorna true se pode continuar, false se bloqueado
  /// Se bloqueado, faz logout automático
  Future<bool> checkSubscriptionBeforeAction() async {
    final result = await AuthService.verificarAssinaturaAtiva();

    if (result['ativo'] != true) {
      // Fazer logout automático
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      return false;
    }

    // Se está em período de graça, mostra aviso mas permite continuar
    if (result['aviso'] == true) {
      _showGracePeriodSnackbar(result['message']);
    }

    return true;
  }

  void _showGracePeriodSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange[700],
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Renovar',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
        ),
      ),
    );
  }
}

/// Função helper para uso em telas que não podem usar mixin
/// Retorna true se pode continuar, false se bloqueado
/// Se bloqueado, faz logout automático e redireciona para login
Future<bool> checkSubscription(BuildContext context) async {
  final result = await AuthService.verificarAssinaturaAtiva();

  if (result['ativo'] != true) {
    // Fazer logout automático e redirecionar para login
    // A popup de bloqueio será mostrada na próxima tentativa de login
    await AuthService.signOut();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
    return false;
  }

  // Se está em período de graça, mostra aviso mas permite continuar
  if (result['aviso'] == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: Colors.orange[700],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  return true;
}
