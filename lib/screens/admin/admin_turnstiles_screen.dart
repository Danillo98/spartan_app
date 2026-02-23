import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../config/app_theme.dart';
import '../../config/supabase_config.dart';
import '../../services/control_id_service.dart';
import '../../services/user_service.dart';
import '../../models/user_role.dart';
import 'support_screen.dart';

class AdminTurnstilesScreen extends StatefulWidget {
  const AdminTurnstilesScreen({super.key});

  @override
  State<AdminTurnstilesScreen> createState() => _AdminTurnstilesScreenState();
}

class IpInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Remove tudo que não for número
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 12) text = text.substring(0, 12);

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 3 == 0) formatted += '.';
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _AdminTurnstilesScreenState extends State<AdminTurnstilesScreen> {
  final _ipController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  Color _statusColor = Colors.grey;
  bool _isConnected = false;

  List<Map<String, dynamic>> _students = [];
  String? _selectedStudentId;

  // Novos campos para Acesso Livre
  bool _isFreeAccess = false;
  final _freeAccessNameController = TextEditingController();

  // Multi-Catraca
  List<String> _savedIps = [];
  Map<String, bool> _ipStatuses = {};
  Timer? _statusTimer;

  final String _downloadUrl =
      '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/downloads/Spartan_Desktop.zip';

  @override
  void initState() {
    super.initState();
    if (_isWindowsApp) {
      _loadSavedIps();
      _loadStudents();
      // Checar status a cada 30 segundos
      _statusTimer = Timer.periodic(
          const Duration(seconds: 30), (_) => _checkAllConnections());
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _freeAccessNameController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  bool get _isWindowsApp {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<void> _loadSavedIps() async {
    final prefs = await SharedPreferences.getInstance();
    // Migração: se tinha o antigo 'control_id_ip', adiciona na lista nova
    final oldIp = prefs.getString('control_id_ip');
    final savedIps = prefs.getStringList('control_id_ips') ?? [];

    if (oldIp != null && !savedIps.contains(oldIp)) {
      savedIps.add(oldIp);
      await prefs.remove('control_id_ip');
    }

    setState(() {
      _savedIps = savedIps;
      if (savedIps.isNotEmpty) {
        _ipController.text = savedIps.first;
      }
    });

    _checkAllConnections();
  }

  Future<void> _saveIps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('control_id_ips', _savedIps);
    // Mantém o primeiro como 'principal' para compatibilidade com o service antigo se necessário
    if (_savedIps.isNotEmpty) {
      await prefs.setString('control_id_ip', _savedIps.first);
    }
  }

  Future<void> _checkAllConnections() async {
    if (!mounted || _savedIps.isEmpty) return;

    for (String ip in _savedIps) {
      final success = await ControlIdService.testConnection(ip);
      if (mounted) {
        setState(() {
          _ipStatuses[ip] = success;
          if (ip == _ipController.text) {
            _isConnected = success;
          }
        });
      }
    }
  }

  Future<void> _removeIp(String ip) async {
    setState(() {
      _savedIps.remove(ip);
      _ipStatuses.remove(ip);
    });
    await _saveIps();
  }

  Future<void> _loadStudents() async {
    final students = await UserService.getUsersByRole(UserRole.student);
    if (mounted) {
      setState(() {
        _students = students;
      });
    }
  }

  Future<void> _testConnection() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Testando conexão...';
      _statusColor = Colors.blue;
    });

    final success = await ControlIdService.testConnection(ip);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isConnected = success;
        _statusMessage = success
            ? 'Conectado com sucesso! Catraca respondendo.'
            : 'Falha ao conectar. Verifique o IP e se estão na mesma rede.';
        _statusColor = success ? Colors.green : Colors.red;

        if (success && !_savedIps.contains(ip)) {
          _savedIps.add(ip);
        }
        _ipStatuses[ip] = success;
      });

      if (success) _saveIps();
    }
  }

  int _generateFreeAccessId(String name) {
    // Range 900.000+ para não conflitar com UUIDs normais
    return 900000 + (name.hashCode.abs() % 99999);
  }

  Future<void> _enrollFace() async {
    final String name = _isFreeAccess
        ? _freeAccessNameController.text.trim()
        : _students.firstWhere((s) => s['id'] == _selectedStudentId)['name'] ??
            'Aluno';

    if (_isFreeAccess && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digite o nome para o Acesso Livre.')));
      return;
    }

    if (!_isFreeAccess && _selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um aluno primeiro.')));
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage =
          'Enviando comando para a catraca... Vá até o dispositivo.';
      _statusColor = Colors.blue;
    });

    try {
      final int catracaId = _isFreeAccess
          ? _generateFreeAccessId(name)
          : ControlIdService.generateCatracaId(_selectedStudentId!);

      // 1. Garante que o usuário existe na catraca
      await ControlIdService.addUser(
        ip: _ipController.text,
        id: catracaId,
        name: name,
      );

      // 2. Dispara o cadastro facial
      final result = await ControlIdService.enrollFaceRemote(
        ip: _ipController.text,
        id: catracaId,
      );

      setState(() {
        _statusMessage = result['success']
            ? 'Câmera ativada para "$name"! Por favor, posicione o rosto.'
            : 'Erro: ${result['message']}';
        _statusColor = result['success'] ? Colors.green : Colors.red;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Erro inesperado: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncAll() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Iniciando Sincronização...';
      _statusColor = Colors.blue;
    });

    try {
      // Sincroniza em todas as catracas salvas
      for (String ip in _savedIps) {
        await ControlIdService.syncAllStudents(ip);
      }

      setState(() {
        _statusMessage = 'Sincronização Concluída em todas as catracas.';
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Erro na sincronização: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _releaseTurnstile() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty || !_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conecte-se à catraca antes de liberar.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Enviando comando de liberação...';
      _statusColor = Colors.blue;
    });

    try {
      final result = await ControlIdService.release(ip);
      setState(() {
        _statusMessage = result['message'];
        _statusColor = result['success'] ? Colors.green : Colors.red;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Erro ao liberar: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchDownloadLink() async {
    final Uri url = Uri.parse(_downloadUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Não foi possível iniciar o download. Verifique sua rede.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStepRow(String number, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEBC115).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFFEBC115),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebInstructions() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecalho de Status
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  const Icon(Icons.sensor_door_rounded,
                      size: 64, color: Color(0xFFEBC115)),
                  const SizedBox(height: 16),
                  Text(
                    'SPARTAN DESKTOP (CONTROL ID)',
                    style: GoogleFonts.cinzel(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A versão Web do seu sistema não pode se comunicar diretamente com dispositivos locais (IP) devido a barreiras de segurança dos navegadores. Para que sua catraca abra as portas, você precisa manter o "Spartan Desktop" rodando em um computador da recepção.',
                    style:
                        TextStyle(fontSize: 16, color: AppTheme.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card de Instalação e Baixa
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[900]!, Colors.black],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.download_for_offline_rounded,
                      size: 56, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'PASSO 1: FAZER O DOWNLOAD',
                    style: GoogleFonts.cinzel(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Baixe agora mesmo a última versão do Spartan Desktop diretamente do nosso servidor oficial.',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _launchDownloadLink,
                    icon:
                        const Icon(Icons.download_rounded, color: Colors.black),
                    label: const Text('BAIXAR AGORA (Windows)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEBC115),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 20),
                      textStyle: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card de Tutoriais
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.borderGrey),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PASSO 2: COMO INICIAR TODOS OS DIAS?',
                    style: GoogleFonts.cinzel(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText),
                  ),
                  const SizedBox(height: 20),
                  _buildStepRow(
                    '1',
                    'Descompacte o arquivo',
                    'Extraia a pasta Spartan_Desktop.zip \n(procure o arquivo na pasta donwloads e clique com o botão direito, em sequida clique em "Extrair Aqui").',
                  ),
                  _buildStepRow(
                    '2',
                    'Abra o Programa',
                    'Abra a pasta Spartan Desktop, execute o arquivo Spartan Desktop.exe e permita a execução no windows (Se abrir a tela do windows e não tiver opção de executar, clique em "Mais Informações" e depois em "Executar assim mesmo").',
                  ),
                  _buildStepRow(
                    '3',
                    'Configure sua Catraca',
                    'Acesse sua conta de administrador no Spartan Desktop e vá em Minhas Catracas na tela inicial. Insira o IP da catraca Control ID e faça os cadastros Faciais. Não esqueça de Sincronizar Manualmente após conectar o IP e realizar um cadastro facial.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    'Caso tenha problemas para executar os passos acima, entre em contato com nosso suporte e descreva o problema',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SupportScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Suporte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEBC115),
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text('MINHAS CATRACAS',
            style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryText),
      ),
      body: _isWindowsApp
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card de Aviso
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD), // Azul suave
                      border: Border.all(color: const Color(0xFFBBDEFB)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user_rounded,
                            color: Color(0xFF1976D2)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Módulo Nativo Ativo. Você tem permissão para acessar a rede local da catraca.',
                            style: TextStyle(color: Color(0xFF0D47A1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dica de como achar IP na Catraca
                  Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300)),
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.help_outline,
                                      color: Color(0xFFEBC115)),
                                  const SizedBox(width: 8),
                                  Text('Como descobrir o IP na catraca?',
                                      style: GoogleFonts.lato(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppTheme.primaryText)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              RichText(
                                  text: const TextSpan(
                                      style: TextStyle(
                                          color: AppTheme.secondaryText,
                                          fontSize: 14),
                                      children: [
                                    TextSpan(
                                        text: '1. Vá até a catraca física.\n'),
                                    TextSpan(
                                        text:
                                            '2. Toque na tela, digite a senha (se houver) e clique no Menu.\n'),
                                    TextSpan(text: '3. Vá em '),
                                    TextSpan(
                                        text: 'Configurações > Rede > IP\n',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue)),
                                    TextSpan(
                                        text:
                                            '4. Digite os números (incluindo os zeros se houverem) no campo abaixo. Exemplo: se na catraca mostra 192.168.001.050, digite exatamente '),
                                    TextSpan(
                                        text: '192168001050',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextSpan(text: ' aqui no computador.\n\n'),
                                    TextSpan(
                                        text: 'DICA: ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red)),
                                    TextSpan(
                                        text:
                                            'Para o melhor funcionamento, configure sua catraca Control ID em modo Standalone no menu físico: (Menu > Acesso > Modo de Operação > Modo Standalone)'),
                                  ])),
                            ],
                          ))),
                  const SizedBox(height: 32),

                  // Configuração de IP
                  Text('Endereço IP da Catraca',
                      style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryText)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ipController,
                          inputFormatters: [IpInputFormatter()],
                          decoration: InputDecoration(
                            hintText: 'Ex: 192.168.1.99',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.wifi_tethering),
                        label: const Text('Conectar'),
                        onPressed: _isLoading ? null : _testConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Lista de Catracas Salvas (Multi-Catraca)
                  if (_savedIps.isNotEmpty) ...[
                    Text('Catracas Configuradas',
                        style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryText)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _savedIps.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final ip = _savedIps[index];
                          final status = _ipStatuses[ip] ?? false;
                          return ListTile(
                            leading: Icon(Icons.memory_rounded,
                                color: status ? Colors.green : Colors.red),
                            title: Text(ip,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              status ? 'Conectado' : 'Desconectado',
                              style: TextStyle(
                                  color: status ? Colors.green : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.sync,
                                      color: Colors.blue, size: 20),
                                  onPressed: () {
                                    setState(() => _ipController.text = ip);
                                    _testConnection();
                                  },
                                  tooltip: 'Reconectar',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  onPressed: () => _removeIp(ip),
                                  tooltip: 'Remover',
                                ),
                              ],
                            ),
                            onTap: () =>
                                setState(() => _ipController.text = ip),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

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

                  // Liberação Imediata (Destaque)
                  Card(
                    elevation: 0,
                    color: const Color(0xFFE8F5E9), // Verde suave
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.green.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(Icons.meeting_room_rounded,
                              color: Colors.green, size: 40),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('LIBERAR CATRACA AGORA',
                                    style: GoogleFonts.lato(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF2E7D32))),
                                const Text(
                                    'Clique no botão ao lado para abrir a catraca remotamente agora.',
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: (_isLoading || !_isConnected)
                                ? null
                                : _releaseTurnstile,
                            icon: const Icon(Icons.lock_open_rounded),
                            label: const Text('ABRIR PORTA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 20),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Ações
                  Text('Ações de Sincronização',
                      style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryText)),
                  const SizedBox(height: 16),

                  // Cadastro Facial Remoto
                  Card(
                    elevation: 0,
                    color: const Color(0xFFF8F9FA),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.face_retouching_natural,
                                      color: Colors.blue),
                                  const SizedBox(width: 10),
                                  Text('Cadastro Facial Remoto',
                                      style: GoogleFonts.lato(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryText)),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('Acesso Livre?',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _isFreeAccess
                                              ? Colors.blue
                                              : Colors.grey)),
                                  const SizedBox(width: 4),
                                  Switch(
                                    value: _isFreeAccess,
                                    activeColor: Colors.blue,
                                    onChanged: (val) {
                                      setState(() {
                                        _isFreeAccess = val;
                                        if (val) _selectedStudentId = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isFreeAccess
                                ? 'Acesso Livre? (Indicado para Funcionários e Não Pagantes)'
                                : 'Selecione um aluno e dispare o comando para a catraca abrir a câmera automaticamente.',
                            style: const TextStyle(
                                color: AppTheme.secondaryText, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          if (!_isFreeAccess)
                            Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.grey.shade300)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    hint: const Row(children: [
                                      Icon(Icons.search,
                                          color: Colors.grey, size: 20),
                                      SizedBox(width: 8),
                                      Text('Pesquisar Aluno pelo nome...'),
                                    ]),
                                    value: _selectedStudentId,
                                    items: _students.map((student) {
                                      return DropdownMenuItem<String>(
                                        value: student['id'],
                                        child: Text(student['name'] ??
                                            student['nome'] ??
                                            'Sem Nome'),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(
                                        () => _selectedStudentId = val),
                                  ),
                                ))
                          else
                            TextField(
                              controller: _freeAccessNameController,
                              decoration: InputDecoration(
                                labelText: 'Nome do Visitante / Funcionário',
                                hintText: 'Digite o nome completo...',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: (_isLoading ||
                                    !_isConnected ||
                                    (!_isFreeAccess &&
                                        _selectedStudentId == null))
                                ? null
                                : _enrollFace,
                            icon: Icon(Icons.camera_alt,
                                color: (_isLoading ||
                                        !_isConnected ||
                                        (!_isFreeAccess &&
                                            _selectedStudentId == null))
                                    ? Colors.grey
                                    : Colors.blue),
                            label: const Text('Câmera: Capturar Rosto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                      color: Colors.blue.withOpacity(0.5))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sincronização Total
                  Card(
                    elevation: 0,
                    color: const Color(0xFFF8F9FA),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sync_alt, color: Colors.blue),
                              const SizedBox(width: 10),
                              Text('Sincronização Total',
                                  style: GoogleFonts.lato(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryText)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                              'Esta ação varre todos os alunos da academia. Alunos com pagamento em dia serão liberados na catraca, e alunos vencidos serão bloqueados permanentemente.',
                              style: TextStyle(color: AppTheme.secondaryText)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed:
                                (_isLoading || !_isConnected) ? null : _syncAll,
                            icon: const Icon(Icons.sync),
                            label: const Text('Sincronizar Manualmente'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildWebInstructions(),
              ),
            ),
    );
  }
}
