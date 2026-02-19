import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_theme.dart';
import '../../services/control_id_service.dart';
import '../../services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTurnstilesScreen extends StatefulWidget {
  const AdminTurnstilesScreen({super.key});

  @override
  State<AdminTurnstilesScreen> createState() => _AdminTurnstilesScreenState();
}

class _AdminTurnstilesScreenState extends State<AdminTurnstilesScreen> {
  final _ipController = TextEditingController(text: '192.168.1.99');
  final _testUserIdController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  Color _statusColor = Colors.grey;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('control_id_ip');
    if (savedIp != null) {
      _ipController.text = savedIp;
    }
  }

  Future<void> _saveIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('control_id_ip', _ipController.text);
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testando conexão...';
      _statusColor = Colors.blue;
    });

    final success = await ControlIdService.testConnection(_ipController.text);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isConnected = success;
        _statusMessage = success
            ? 'Conectado com sucesso! Catraca respondendo.'
            : 'Falha ao conectar. Verifique o IP e se estão na mesma rede.';
        _statusColor = success ? Colors.green : Colors.red;
      });

      if (success) _saveIp();
    }
  }

  Future<void> _syncTestUser() async {
    if (_testUserIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digite o ID do usuário para teste')));
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Sincronizando usuário de teste...';
    });

    try {
      final userId = int.tryParse(_testUserIdController.text);
      if (userId == null) throw 'ID inválido';

      // Busca dados reais do usuário no Supabase para garantir permissão
      // Mas para teste, vamos confiar no ID digitado e nome "Usuario Teste"
      // Ou melhor, buscar o nome se possível.

      // Simulação de busca rápida ou uso do nome genérico
      final result = await ControlIdService.addUser(
        ip: _ipController.text,
        id: userId,
        name: 'Usuario Teste $userId', // Nome genérico para teste rápido
        // password: admin (padrão no service)
      );

      setState(() {
        _statusMessage = result['success']
            ? 'Sucesso! Usuário $userId enviado para a Lista Branca.'
            : 'Erro: ${result['message']}';
        _statusColor = result['success'] ? Colors.green : Colors.red;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Erro: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text('Minhas Catracas',
            style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card de Aviso
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                border: Border.all(color: const Color(0xFFFFECB5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFF856404)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Esta configuração é exclusiva para catracas Control iD (iDFace/iDAccess). '
                      'Certifique-se que este computador está na mesma rede Wi-Fi/Cabo da catraca.',
                      style: TextStyle(color: Color(0xFF856404)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Configuração de IP
            Text('Endereço IP da Catraca',
                style: GoogleFonts.lato(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                hintText: 'Ex: 192.168.1.99',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Testar Conexão',
                  onPressed: _isLoading ? null : _testConnection,
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Status da Conexão
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                      color: _statusColor, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 32),

            // Ações (Só aparecem se conectado ou se quiser forçar)
            Text('Ações de Sincronização',
                style: GoogleFonts.lato(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Modo Teste
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.science, color: Colors.blue),
                        const SizedBox(width: 10),
                        Text('Modo Teste (Seguro)',
                            style: GoogleFonts.lato(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                        'Sincroniza apenas UM usuário específico para validar a comunicação sem alterar os outros.'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _testUserIdController,
                      decoration: const InputDecoration(
                        labelText: 'ID do Usuário (ex: 9999)',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isLoading || !_isConnected)
                            ? null
                            : _syncTestUser,
                        icon: const Icon(Icons.sync),
                        label: const Text('Sincronizar Apenas Este ID'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
