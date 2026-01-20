import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// TESTE SIMPLES DE ENVIO DE EMAIL
/// Execute este código para verificar se o Supabase está enviando emails
class EmailTestScreen extends StatefulWidget {
  const EmailTestScreen({Key? key}) : super(key: key);

  @override
  State<EmailTestScreen> createState() => _EmailTestScreenState();
}

class _EmailTestScreenState extends State<EmailTestScreen> {
  final _emailController =
      TextEditingController(text: 'danilloneto98@gmail.com');
  final _passwordController = TextEditingController(text: 'teste123456');
  bool _loading = false;
  String _result = '';

  Future<void> _testEmail() async {
    setState(() {
      _loading = true;
      _result = '';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty) {
        setState(() {
          _result = '❌ Digite um email válido';
          _loading = false;
        });
        return;
      }

      // TESTE 1: Verificar se email já existe
      print('🔍 Verificando se email já existe...');
      final existingUsers = await Supabase.instance.client
          .from('users_adm')
          .select('email')
          .eq('email', email);

      if (existingUsers.isNotEmpty) {
        setState(() {
          _result = '⚠️ Email já cadastrado! Delete primeiro:\n\n'
              'DELETE FROM auth.users WHERE email = \'$email\';\n'
              'DELETE FROM public.users WHERE email = \'$email\';';
          _loading = false;
        });
        return;
      }

      print('✅ Email disponível');

      // TESTE 2: Criar usuário no Supabase Auth
      print('📧 Criando usuário e enviando email...');
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'http://localhost:3000/confirm',
      );

      print('✅ Resposta recebida');
      print('User ID: ${response.user?.id}');
      print('Email: ${response.user?.email}');
      print('Email Confirmed: ${response.user?.emailConfirmedAt}');

      // Fazer logout imediato
      await Supabase.instance.client.auth.signOut();
      print('✅ Logout realizado');

      setState(() {
        _result = '''
✅ SUCESSO!

📧 Email enviado para: $email

📋 Detalhes:
- User ID: ${response.user?.id}
- Email confirmado: ${response.user?.emailConfirmedAt ?? 'Aguardando confirmação'}

⏰ PRÓXIMOS PASSOS:
1. Verifique seu email (pode demorar 1-2 minutos)
2. Procure em TODAS as pastas (Inbox, Spam, Lixo)
3. Remetente: noreply@mail.app.supabase.io
4. Se não chegar em 2 minutos, há problema na configuração do Supabase

🔍 VERIFICAR CONFIGURAÇÃO:
1. Supabase Dashboard → Authentication → Settings
2. "Enable email confirmations" deve estar ON
3. "Confirm email" deve estar ON
4. Template "Confirm signup" deve estar configurado
''';
        _loading = false;
      });
    } catch (e) {
      print('❌ ERRO: $e');
      setState(() {
        _result = '''
❌ ERRO AO ENVIAR EMAIL

Erro: $e

🔍 POSSÍVEIS CAUSAS:

1. Email já existe no Supabase
   → Solução: Delete o usuário primeiro

2. Configuração do Supabase incorreta
   → Solução: Verifique Authentication → Settings

3. Email inválido
   → Solução: Use um email real (Gmail, Outlook, etc)

4. Senha muito curta
   → Solução: Use senha com 6+ caracteres

📋 PARA DELETAR USUÁRIO EXISTENTE:
Execute no SQL Editor do Supabase:

DELETE FROM auth.users WHERE email = '${_emailController.text}';
DELETE FROM public.users WHERE email = '${_emailController.text}';
''';
        _loading = false;
      });
    }
  }

  Future<void> _checkSupabaseConfig() async {
    setState(() {
      _loading = true;
      _result = '';
    });

    try {
      // Verificar se consegue conectar ao Supabase
      await Supabase.instance.client.from('users').select().limit(1);

      setState(() {
        _result = '''
✅ CONEXÃO COM SUPABASE OK

📋 CHECKLIST DE CONFIGURAÇÃO:

Acesse: https://supabase.com/dashboard

1. Authentication → Settings:
   ☐ Enable email provider: ON
   ☐ Confirm email: ON
   ☐ Enable email confirmations: ON

2. Authentication → Email Templates:
   ☐ Template "Confirm signup" configurado
   ☐ Template em português (opcional)
   ☐ Usa {{ .ConfirmationURL }}

3. Authentication → URL Configuration:
   ☐ Site URL: http://localhost:3000
   ☐ Redirect URLs: http://localhost:3000/*

4. SQL Editor:
   ☐ Tabela "users" existe
   ☐ Tabela tem coluna "email"

✅ Se tudo estiver OK, o email DEVE ser enviado!
''';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _result = '''
❌ ERRO DE CONEXÃO COM SUPABASE

Erro: $e

🔍 VERIFIQUE:
1. Arquivo lib/services/supabase_service.dart
2. URL e API Key estão corretos?
3. Internet está funcionando?
''';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Teste de Email'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '📧 Teste de Envio de Email',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use este teste para verificar se o Supabase está enviando emails corretamente.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Email
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Seu Email Real',
                hintText: 'seu-email@gmail.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Senha
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Senha de Teste',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            // Botão: Testar Email
            ElevatedButton.icon(
              onPressed: _loading ? null : _testEmail,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label:
                  Text(_loading ? 'Enviando...' : '📧 Testar Envio de Email'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),

            // Botão: Verificar Configuração
            OutlinedButton.icon(
              onPressed: _loading ? null : _checkSupabaseConfig,
              icon: const Icon(Icons.settings),
              label: const Text('⚙️ Verificar Configuração'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 32),

            // Resultado
            if (_result.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _result.startsWith('✅')
                      ? Colors.green.shade50
                      : _result.startsWith('⚠️')
                          ? Colors.orange.shade50
                          : Colors.red.shade50,
                  border: Border.all(
                    color: _result.startsWith('✅')
                        ? Colors.green
                        : _result.startsWith('⚠️')
                            ? Colors.orange
                            : Colors.red,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _result,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
