// ============================================
// EXEMPLOS PRÁTICOS DE USO - SEGURANÇA
// ============================================

// Este arquivo contém exemplos de como usar os serviços de segurança
// implementados no aplicativo Spartan Gym

import 'package:flutter/material.dart';
import '../services/auth_service_secure.dart';
import '../services/audit_log_service.dart';
import '../services/rate_limit_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/validators.dart';
import '../models/user_role.dart';

// ============================================
// EXEMPLO 1: LOGIN SEGURO
// ============================================

class SecureLoginExample extends StatefulWidget {
  const SecureLoginExample({super.key});

  @override
  State<SecureLoginExample> createState() => _SecureLoginExampleState();
}

class _SecureLoginExampleState extends State<SecureLoginExample> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      // 1. Validar email antes de enviar
      if (!Validators.isValidEmail(_emailController.text)) {
        _showError('Email inválido');
        return;
      }

      // 2. Verificar se não está bloqueado por rate limit
      if (!RateLimitService.canAttemptLogin(_emailController.text)) {
        final blockedTime =
            RateLimitService.getLoginBlockedTime(_emailController.text);
        _showError('Muitas tentativas. Aguarde $blockedTime minutos');
        return;
      }

      // 3. Tentar fazer login (já inclui todas as proteções)
      final result = await AuthServiceSecure.signIn(
        email: _emailController.text,
        password: _passwordController.text,
        expectedRole: UserRole.admin,
      );

      if (result['success']) {
        // Login bem-sucedido
        _showSuccess(result['message']);
        // Navegar para dashboard
      } else {
        // Login falhou
        _showError(result['message']);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// EXEMPLO 2: REGISTRO COM VALIDAÇÕES
// ============================================

class SecureRegisterExample extends StatefulWidget {
  const SecureRegisterExample({super.key});

  @override
  State<SecureRegisterExample> createState() => _SecureRegisterExampleState();
}

class _SecureRegisterExampleState extends State<SecureRegisterExample> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _addressController = TextEditingController();

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nome é obrigatório';
    }
    if (!Validators.isValidName(value)) {
      return 'Nome inválido. Use apenas letras';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email é obrigatório';
    }
    if (!Validators.isValidEmail(value)) {
      return 'Email inválido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Senha é obrigatória';
    }

    final validation = Validators.validatePassword(value);
    if (!validation['isValid']) {
      final errors = validation['errors'] as List<String>;
      return errors.first;
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Telefone é obrigatório';
    }
    if (!Validators.isValidPhone(value)) {
      return 'Telefone inválido. Use: (XX) XXXXX-XXXX';
    }
    return null;
  }

  String? _validateCPF(String? value) {
    if (value == null || value.isEmpty) {
      return 'CPF é obrigatório';
    }
    if (!Validators.isValidCPF(value)) {
      return 'CPF inválido';
    }
    return null;
  }

  String? _validateCNPJ(String? value) {
    if (value == null || value.isEmpty) {
      return 'CNPJ é obrigatório';
    }
    if (!Validators.isValidCNPJ(value)) {
      return 'CNPJ inválido';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final result = await AuthServiceSecure.registerAdmin(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phone: _phoneController.text,
      cpf: _cpfController.text,
      cnpj: _cnpjController.text,
      address: _addressController.text,
    );

    if (result['success']) {
      // Registro bem-sucedido
      _showSuccess(result['message']);
    } else {
      // Registro falhou
      _showError(result['message']);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: _validateName,
            ),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: _validateEmail,
            ),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
              validator: _validatePassword,
            ),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefone'),
              validator: _validatePhone,
            ),
            TextFormField(
              controller: _cpfController,
              decoration: const InputDecoration(labelText: 'CPF'),
              validator: _validateCPF,
            ),
            TextFormField(
              controller: _cnpjController,
              decoration: const InputDecoration(labelText: 'CNPJ'),
              validator: _validateCNPJ,
            ),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Endereço'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleRegister,
              child: const Text('Cadastrar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// EXEMPLO 3: VERIFICAÇÃO DE SESSÃO
// ============================================

class SessionCheckExample extends StatefulWidget {
  const SessionCheckExample({super.key});

  @override
  State<SessionCheckExample> createState() => _SessionCheckExampleState();
}

class _SessionCheckExampleState extends State<SessionCheckExample> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Verifica se está autenticado e sessão é válida
    final isAuthenticated = await AuthServiceSecure.isAuthenticated();

    if (!isAuthenticated) {
      // Sessão inválida ou expirada, redirecionar para login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ============================================
// EXEMPLO 4: VISUALIZAR LOGS DE AUDITORIA (ADMIN)
// ============================================

class AuditLogsExample extends StatefulWidget {
  const AuditLogsExample({super.key});

  @override
  State<AuditLogsExample> createState() => _AuditLogsExampleState();
}

class _AuditLogsExampleState extends State<AuditLogsExample> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    // Buscar logs dos últimos 7 dias
    final logs = await AuditLogService.getLogsByDateRange(
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      endDate: DateTime.now(),
      limit: 50,
    );

    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _loadCriticalLogs() async {
    setState(() => _isLoading = true);

    final logs = await AuditLogService.getCriticalLogs(limit: 20);

    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs de Auditoria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning),
            onPressed: _loadCriticalLogs,
            tooltip: 'Ver logs críticos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return ListTile(
                  leading: _getSeverityIcon(log['severity']),
                  title: Text(log['event_type'] ?? 'Evento'),
                  subtitle: Text(log['description'] ?? ''),
                  trailing: Text(
                    _formatDate(log['timestamp']),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
    );
  }

  Icon _getSeverityIcon(String? severity) {
    switch (severity) {
      case 'critical':
        return const Icon(Icons.error, color: Colors.red);
      case 'error':
        return const Icon(Icons.warning, color: Colors.orange);
      case 'warning':
        return const Icon(Icons.info, color: Colors.yellow);
      default:
        return const Icon(Icons.check_circle, color: Colors.green);
    }
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.parse(timestamp);
    return '${date.day}/${date.month} ${date.hour}:${date.minute}';
  }
}

// ============================================
// EXEMPLO 5: INDICADOR DE FORÇA DA SENHA
// ============================================

class PasswordStrengthIndicator extends StatefulWidget {
  final TextEditingController controller;

  const PasswordStrengthIndicator({
    super.key,
    required this.controller,
  });

  @override
  State<PasswordStrengthIndicator> createState() =>
      _PasswordStrengthIndicatorState();
}

class _PasswordStrengthIndicatorState extends State<PasswordStrengthIndicator> {
  int _strength = 0;
  List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_checkStrength);
  }

  void _checkStrength() {
    final validation = Validators.validatePassword(widget.controller.text);
    setState(() {
      _strength = validation['strength'] as int;
      _errors = validation['errors'] as List<String>;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: _strength / 100,
          backgroundColor: Colors.grey[300],
          color: _getStrengthColor(),
        ),
        const SizedBox(height: 8),
        Text(
          _getStrengthText(),
          style: TextStyle(
            color: _getStrengthColor(),
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...(_errors.map((error) => Text(
                '• $error',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ))),
        ],
      ],
    );
  }

  Color _getStrengthColor() {
    if (_strength >= 80) return Colors.green;
    if (_strength >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getStrengthText() {
    if (_strength >= 80) return 'Senha forte';
    if (_strength >= 60) return 'Senha média';
    if (_strength >= 40) return 'Senha fraca';
    return 'Senha muito fraca';
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkStrength);
    super.dispose();
  }
}
