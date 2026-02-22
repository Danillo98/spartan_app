import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import '../services/control_id_service.dart';

class MotorCatracaScreen extends StatefulWidget {
  const MotorCatracaScreen({super.key});

  @override
  State<MotorCatracaScreen> createState() => _MotorCatracaScreenState();
}

class _MotorCatracaScreenState extends State<MotorCatracaScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _isRunning = false;
  String _statusMessage = 'Aguardando inicialização...';
  final List<String> _logs = [];

  RealtimeChannel? _alunosChannel;
  RealtimeChannel? _financialChannel;
  bool _isSyncingManual = false;
  bool _autoStart = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunchAndCreateDesktopShortcut();
    _checkAutoStart();
    _loadIpAndStart();
  }

  Future<void> _checkFirstLaunchAndCreateDesktopShortcut() async {
    if (!Platform.isWindows) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch =
          prefs.getBool('first_launch_desktop_shortcut_v4') ?? true;
      if (isFirstLaunch) {
        final r = await Process.run(
            'powershell', ['-c', '[Environment]::GetFolderPath("Desktop")']);
        if (r.stdout != null && r.stdout.toString().trim().isNotEmpty) {
          final desktopPath = r.stdout.toString().trim();
          final shortcutPath = '$desktopPath\\Motor Spartan.lnk';
          final exePath = Platform.resolvedExecutable;
          final dirPath = File(exePath).parent.path;

          final script =
              "\$w=(New-Object -COM WScript.Shell);\$s=\$w.CreateShortcut('$shortcutPath');\$s.TargetPath='$exePath';\$s.WorkingDirectory='$dirPath';\$s.Save()";
          final r2 = await Process.run('powershell', ['-c', script]);
          if (r2.stderr != null && r2.stderr.toString().isNotEmpty) {
            debugPrint('Powershell error: \${r2.stderr}');
          } else {
            await prefs.setBool('first_launch_desktop_shortcut_v4', false);
          }
        }
      }
    } catch (e) {
      debugPrint("Desktop Shortcut Error: $e");
    }
  }

  Future<void> _checkAutoStart() async {
    if (!Platform.isWindows) return;
    try {
      final r = await Process.run(
          'powershell', ['-c', '[Environment]::GetFolderPath("Startup")']);
      if (r.stdout != null && r.stdout.toString().trim().isNotEmpty) {
        final path = r.stdout.toString().trim() + '\\MotorSpartan.lnk';
        final exists = await File(path).exists();
        if (mounted) {
          setState(() {
            _autoStart = exists;
          });
        }
      }
    } catch (e) {
      debugPrint("AutoStart Check Error: $e");
    }
  }

  Future<void> _toggleAutoStart(bool value) async {
    if (!Platform.isWindows) return;
    try {
      final r = await Process.run(
          'powershell', ['-c', '[Environment]::GetFolderPath("Startup")']);
      if (r.stdout != null && r.stdout.toString().trim().isNotEmpty) {
        final startupPath = r.stdout.toString().trim();
        final shortcutPath = '$startupPath\\MotorSpartan.lnk';
        final exePath = Platform.resolvedExecutable;
        final dirPath = File(exePath).parent.path;

        if (value) {
          final script =
              "\$w=(New-Object -COM WScript.Shell);\$s=\$w.CreateShortcut('$shortcutPath');\$s.TargetPath='$exePath';\$s.WorkingDirectory='$dirPath';\$s.Save()";
          await Process.run('powershell', ['-c', script]);
        } else {
          final file = File(shortcutPath);
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
        setState(() {
          _autoStart = value;
        });
      }
    } catch (e) {
      _addLog('❌ ERRO ao configurar inicialização automática.');
    }
  }

  Future<void> _loadIpAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('control_id_ip');
    if (savedIp != null && savedIp.isNotEmpty) {
      _ipController.text = savedIp;
      // Espera um pouco pra montar o widget na tela
      await Future.delayed(const Duration(seconds: 1));
      _startMotor();
    } else {
      setState(() {
        _statusMessage = 'Configure o IP e inicie o motor.';
      });
    }
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0,
          "[${DateTime.now().toIso8601String().split('T').last.substring(0, 8)}] $msg");
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  Future<void> _startMotor() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _addLog('❌ ERRO: IP Inválido');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('control_id_ip', ip);

    setState(() {
      _isRunning = true;
      _statusMessage = 'Testando conexão com a Catraca...';
    });

    _addLog('Iniciando comunicação com $ip...');
    bool connected = await ControlIdService.testConnection(ip);

    if (!connected) {
      setState(() {
        _isRunning = false;
        _statusMessage = 'Conexão com a catraca falhou!';
      });
      _addLog('❌ ERRO: Não foi possível conectar a $ip.');
      return;
    }

    setState(() {
      _statusMessage = 'Sincronizando alunos (Inicialização)...';
    });
    _addLog('Baixando alunos do Supabase e sincronizando acesso...');

    // Roda sincronização silenciosa
    await ControlIdService.syncAllStudentsSilently();
    _addLog('✅ Sincronização global inicial concluída.');

    setState(() {
      _statusMessage = 'Conectado com a catraca!';
    });

    _startRealtimeListeners();
  }

  void _stopMotor() {
    _alunosChannel?.unsubscribe();
    _financialChannel?.unsubscribe();
    setState(() {
      _isRunning = false;
      _statusMessage = 'Motor Parado';
    });
    _addLog('Monitoramento interrompido pelo usuário.');
  }

  Future<void> _syncManual() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _addLog('❌ ERRO: Configure o IP para sincronizar.');
      return;
    }

    setState(() {
      _isSyncingManual = true;
    });

    _addLog('Iniciando sincronização manual...');
    try {
      final connected = await ControlIdService.testConnection(ip);
      if (!connected) {
        _addLog('❌ ERRO: Catraca offline ou ausente.');
      } else {
        await ControlIdService.syncAllStudentsSilently();
        _addLog('✅ Sincronização manual concluída.');
      }
    } catch (e) {
      _addLog('❌ ERRO inesperado (Sincronização Manual): $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingManual = false;
        });
      }
    }
  }

  void _startRealtimeListeners() {
    _addLog('Ativando WebSockets de monitoramento...');

    _alunosChannel = Supabase.instance.client
        .channel('public:users_alunos:motor')
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'users_alunos',
            callback: (payload) async {
              await Future.delayed(const Duration(milliseconds: 1500));
              final newRecord = payload.newRecord;
              if (newRecord.containsKey('id')) {
                _addLog('🔔 Alerta (Cadastro): Mudança em Aluno detectada!');
                await ControlIdService.syncStudentRealtime(newRecord['id']);
                _addLog('✅ Acesso atualizado!');
              }
            })
        .subscribe();

    _financialChannel = Supabase.instance.client
        .channel('public:financial_transactions:motor')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'financial_transactions',
            callback: (payload) async {
              await Future.delayed(const Duration(milliseconds: 1500));
              final record = payload.newRecord.isNotEmpty
                  ? payload.newRecord
                  : payload.oldRecord;

              if (record.containsKey('related_user_id')) {
                _addLog('🔔 Alerta (Finanças): Nova transação financeira.');
                await ControlIdService.syncStudentRealtime(
                    record['related_user_id']);
                _addLog('✅ Acesso atualizado!');
              } else if (payload.eventType == PostgresChangeEvent.delete) {
                _addLog('🔔 Alerta (Finanças): Estorno Global Detectado!');
                await ControlIdService.syncAllStudentsSilently();
                _addLog('✅ Travamento global atualizado!');
              }
            })
        .subscribe();

    _addLog('✅ Motor ativo e conectando diretamente na catraca.');
  }

  @override
  void dispose() {
    _stopMotor();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Spartan - Motor da Catraca'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ipController,
                      enabled: !_isRunning,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'IP Local da Catraca (ex: 192.168.1.99)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.help_outline,
                              color: Colors.amber),
                          tooltip: 'Como descobrir o IP?',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF2E2E2E),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                title: const Text('Como descobrir o IP?',
                                    style: TextStyle(color: Colors.white)),
                                content: const Text(
                                  'A maioria das catracas Control iD possui uma tela interativa ou menu próprio:\n\n'
                                  '1. Vá até a catraca física.\n'
                                  '2. Acesse o [Menu] principal.\n'
                                  '3. Navegue até [Configurações] e em seguida [Rede].\n'
                                  '4. Anote o número do "Endereço IP" exibido na tela (Ex: 192.168.1.25).\n'
                                  '5. Digite este exato número aqui no computador.\n\n'
                                  'Lembre-se: O computador precisa estar ligado na mesma rede/roteador da catraca!',
                                  style: TextStyle(
                                      color: Colors.white70, height: 1.5),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('ENTENDI',
                                        style: TextStyle(color: Colors.amber)),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isRunning ? _stopMotor : _startMotor,
                      icon: Icon(
                        _isRunning
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isRunning ? 'PARAR MOTOR' : 'INICIAR MOTOR',
                        style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isRunning ? Colors.red : Colors.green[700],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (Platform.isWindows)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CheckboxListTile(
                  title: const Text(
                    'Iniciar automaticamente ao ligar o computador',
                    style: TextStyle(color: Colors.white70),
                  ),
                  value: _autoStart,
                  onChanged: (val) {
                    if (val != null) _toggleAutoStart(val);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.amber,
                  checkboxShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: _isRunning
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                border: Border.all(
                    color: _isRunning ? Colors.green : Colors.red, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isRunning ? Colors.green : Colors.red,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isRunning) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSyncingManual ? null : _syncManual,
                  icon: _isSyncingManual
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.sync_rounded, color: Colors.black),
                  label: Text(
                    _isSyncingManual
                        ? 'Sincronizando...'
                        : 'Sincronizar Manualmente',
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEBC115),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Logs do Sistema em Tempo Real',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListView.builder(
                  reverse: false,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: log.contains('ERRO')
                              ? Colors.redAccent
                              : (log.contains('✅') || log.contains('🔔')
                                  ? Colors.greenAccent
                                  : Colors.white70),
                          fontFamily: 'Courier',
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
