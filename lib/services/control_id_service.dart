import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'financial_service.dart';

class ControlIdService {
  // Histórico persistente que sobrevive à mudança de telas (Memória de Sessão)
  static final List<Map<String, dynamic>> accessLogHistory = [];
  static final Map<String, int> _lastProcessedLogIds = {};
  static String? _session;

  // Realtime persistente (singleton) — sobrevive à troca de telas no Spartan Desktop
  static RealtimeChannel? _persistentAlunosChannel;
  static RealtimeChannel? _persistentFinancialChannel;
  static bool _realtimeActive = false;

  static int getLastProcessedLogId(String ip) => _lastProcessedLogIds[ip] ?? 0;

  static void addLogToHistory(Map<String, dynamic> log, String ip) {
    if (log['log_id'] != null && log['log_id'] > 0) {
      bool exists = accessLogHistory
          .any((l) => l['log_id'] == log['log_id'] && l['terminal_ip'] == ip);
      if (exists) return;

      final currentLastId = _lastProcessedLogIds[ip] ?? 0;
      if (log['log_id'] > currentLastId) {
        _lastProcessedLogIds[ip] = log['log_id'];
      }
    }

    // Adiciona o IP ao log para facilitar identificação e evitar duplicatas cruzadas
    final enrichedLog = Map<String, dynamic>.from(log);
    enrichedLog['terminal_ip'] = ip;

    accessLogHistory.insert(0, enrichedLog);

    // Limita log para não pesar memória (200 registros)
    if (accessLogHistory.length > 200) {
      accessLogHistory.removeLast();
    }
  }

  static Future<Map<String, dynamic>> addUser({
    required String ip,
    required int id,
    required String name,
  }) async {
    try {
      final sanitizedIp = sanitizeIp(ip);

      // 1. Criar ou atualizar usuário (com retry automático em caso de sessão expirada)
      final createUserBody = jsonEncode({
        "object": "users",
        "values": [
          {"id": id, "name": name, "registration": id.toString(), "password": ""}
        ]
      });

      final resCreate = await _withSession(sanitizedIp, (session) =>
        http.post(
          Uri.parse('http://$sanitizedIp/create_objects.fcgi?session=$session'),
          headers: {'Content-Type': 'application/json'},
          body: createUserBody,
        ).timeout(const Duration(seconds: 8))
      );

      // Se falhar por outro motivo (usuário já existe), usa modify_objects
      if (resCreate.statusCode != 200) {
        final modifyUserBody = jsonEncode({
          "object": "users",
          "values": {"name": name},
          "where": {"users": {"id": id}}
        });
        // Pega a sessão atual (já renovada se necessário pelo _withSession acima)
        final session = _session ?? '';
        if (session.isNotEmpty) {
          await http.post(
            Uri.parse('http://$sanitizedIp/modify_objects.fcgi?session=$session'),
            headers: {'Content-Type': 'application/json'},
            body: modifyUserBody,
          ).timeout(const Duration(seconds: 8));
        }
      }

      // 2. Criar ou restaurar o vínculo com a Regra de Acesso padrão (ID 1 = 24h)
      final ruleBody = jsonEncode({
        "object": "user_access_rules",
        "values": [{"user_id": id, "access_rule_id": 1}]
      });

      // Retry automático também aqui (se a sessão expirou entre os dois passos)
      await _withSession(sanitizedIp, (session) =>
        http.post(
          Uri.parse('http://$sanitizedIp/create_objects.fcgi?session=$session'),
          headers: {'Content-Type': 'application/json'},
          body: ruleBody,
        ).timeout(const Duration(seconds: 8))
      );

      return {'success': true, 'message': 'Usuário sincronizado e liberado!'};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// Invalida a sessão atual, forçando novo login na próxima chamada
  static void _invalidateSession() {
    _session = null;
  }

  /// Executa uma chamada à API da catraca com retry automático em caso de sessão expirada.
  /// Se receber 401/403, invalida a sessão, faz novo login (invisivel, em background ~100ms)
  /// e repete a requisição UMA vez. Tudo acontece silenciosamente sem tocar na tela.
  static Future<http.Response> _withSession(
    String ip,
    Future<http.Response> Function(String session) request,
  ) async {
    final sanitizedIp = sanitizeIp(ip);
    String session = await _login(sanitizedIp);
    if (session.isEmpty) throw Exception('Não foi possível conectar à catraca');

    final response = await request(session);

    // Se a sessão expirou, renova e tenta mais uma vez (invisible retry)
    if (response.statusCode == 401 || response.statusCode == 403) {
      print('⚠️ [Control iD] Sessão expirada. Renovando automaticamente...');
      _invalidateSession();
      session = await _login(sanitizedIp);
      if (session.isEmpty) throw Exception('Falha ao renovar sessão da catraca');
      print('✅ [Control iD] Sessão renovada! Repetindo requisição...');
      return request(session);
    }

    return response;
  }

  /// Tenta logar e retornar o session ID
  /// Sempre força novo login se a sessão atual for inválida
  static Future<String> _login(String ip) async {
    if (_session != null && _session!.isNotEmpty) return _session!;

    try {
      final url = Uri.parse('http://$ip/login.fcgi');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"login": "admin", "password": "admin"}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _session = data['session'] ?? '';
        return _session!;
      } else {
        print('⚠️ [Control iD] Login falhou com status: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ [Control iD] Erro no login: $e');
    }
    _session = null;
    return '';
  }

  /// Verifica conexão com a catraca (Ping)
  static Future<bool> testConnection(String ip) async {
    try {
      final sanitizedIp = sanitizeIp(ip);
      // Tenta login como ping
      final session = await _login(sanitizedIp);
      return session.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Limpa zeros à esquerda e espaços do IP (ex: 192.168.001.050 -> 192.168.1.50)
  static String sanitizeIp(String ip) {
    if (ip.isEmpty) return ip;
    try {
      return ip.trim().split('.').map((part) {
        return int.parse(part).toString();
      }).join('.');
    } catch (e) {
      return ip.trim(); // Se falhar o parse (ex: ip invalido), retorna trimado
    }
  }

  /// Ativa a câmera da Catraca para cadastrar o rosto de um aluno específico remotamente
  static Future<Map<String, dynamic>> enrollFaceRemote({
    required String ip,
    required int id,
  }) async {
    try {
      final sanitizedIp = sanitizeIp(ip);
      String session = await _login(sanitizedIp);
      if (session.isEmpty) throw 'Falha ao autenticar na catraca';

      final urlWithSession =
          Uri.parse('http://$sanitizedIp/remote_enroll.fcgi?session=$session');

      final body = jsonEncode({
        "type": "face",
        "user_id": id,
        "save": true,
        "sync": false,
        "auto": true, // A foto bate sozinha quando o aluno olha
        "flash": true, // NOVO: Liga o flash/LED para melhorar a iluminação
        "msg": "Olhe para a camera"
      });

      final response = await http.post(
        urlWithSession,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Câmera ativada! Peça para o aluno olhar para a catraca.'
        };
      } else {
        return {
          'success': false,
          'message': 'Erro da Catraca: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erro de rede: $e'};
    }
  }

  /// Gera um ID numérico (compatível com a catraca) a partir do UUID do Supabase

  static int generateCatracaId(String uuid) {
    if (uuid.isEmpty) return 0;
    // Pega a primeira parte do UUID (8 caracteres hexadecimais = 32 bits)
    final firstPart = uuid.split('-').first;
    // Tenta fazer o parse para int, garantindo maximo de 4.29 bilhões
    return int.parse(firstPart, radix: 16);
  }

  /// Remove o ACESSO de um usuário da Control iD (Bloqueio/Inadimplente)
  /// NOTA: Não deleta o usuário para evitar perder Fotos/Biometria! Apenas remove a regra de entrada.
  static Future<Map<String, dynamic>> removeUser({
    required String ip,
    required int id,
  }) async {
    try {
      final sanitizedIp = sanitizeIp(ip);

      final body = jsonEncode({
        "object": "user_access_rules",
        "where": {"user_access_rules": {"user_id": id}}
      });

      // Retry automático: se a sessão expirar, renova e tenta de novo invisvelmente
      final response = await _withSession(sanitizedIp, (session) =>
        http.post(
          Uri.parse('http://$sanitizedIp/destroy_objects.fcgi?session=$session'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        ).timeout(const Duration(seconds: 8))
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Usuário bloqueado com sucesso (Biometria mantida).'};
      } else {
        return {'success': false, 'message': 'Erro da catraca: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// Carrega objetos cadastrados na catraca
  /// Retorna null se houver falha de rede/conexão para permitir fallback seguro
  static Future<List<Map<String, dynamic>>?> loadObjects({
    required String ip,
    required String object,
  }) async {
    try {
      final sanitizedIp = sanitizeIp(ip);

      final bodyEncoded = jsonEncode({"object": object});

      // Retry automático: se a sessão expirar, renova e tenta de novo invisivelmente
      final response = await _withSession(sanitizedIp, (session) =>
        http.post(
          Uri.parse('http://$sanitizedIp/load_objects.fcgi?session=$session'),
          headers: {'Content-Type': 'application/json'},
          body: bodyEncoded,
        ).timeout(const Duration(seconds: 10))
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data[object];
        if (list is List) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (e) {
      print('⚠️ [Control iD] Erro ao carregar $object: $e');
    }
    return null;
  }

  /// Sincroniza TODOS os alunos da academia atual para a Catraca
  static Future<Map<String, dynamic>> syncAllStudents(String ip) async {
    try {
      final now = DateTime.now();
      // Busca a lista atualizada de alunos e seus status (paid, pending, overdue)
      final studentsStatus = await FinancialService.getMonthlyPaymentsStatus(
          month: now.month, year: now.year);

      int addedCount = 0;
      int removedCount = 0;

      // 1. Tenta carregar o estado atual da catraca para sincronização inteligente (Smart Diff)
      final List<Map<String, dynamic>>? catracaUsers = await loadObjects(ip: ip, object: 'users');
      final List<Map<String, dynamic>>? catracaRules = await loadObjects(ip: ip, object: 'user_access_rules');

      Set<int>? existingUserIds;
      Set<int>? activeRuleUserIds;

      if (catracaUsers != null && catracaRules != null) {
        existingUserIds = catracaUsers
            .map((u) => int.tryParse(u['id'].toString()) ?? 0)
            .where((id) => id > 0)
            .toSet();

        activeRuleUserIds = catracaRules
            .where((r) => int.tryParse(r['access_rule_id'].toString()) == 1)
            .map((r) => int.tryParse(r['user_id'].toString()) ?? 0)
            .where((id) => id > 0)
            .toSet();
            
        print('⚡ [Control iD] Modo Smart Diff Ativado! Usuários na catraca: ${existingUserIds.length}, Regras ativas: ${activeRuleUserIds.length}');
      } else {
        print('⚠️ [Control iD] Falha ao ler dados da catraca. Executando sincronização completa (Fallback).');
      }

      // Dividir os estudantes em chunks (lotes) de execução paralela para não travar a catraca
      const int chunkSize = 10;
      
      for (int i = 0; i < studentsStatus.length; i += chunkSize) {
        final end = (i + chunkSize < studentsStatus.length) 
            ? i + chunkSize 
            : studentsStatus.length;
        final chunk = studentsStatus.sublist(i, end);

        // Executa o chunk atual em paralelo
        await Future.wait(chunk.map((student) async {
          final String uuid = student['id'];
          final int catracaId = generateCatracaId(uuid);
          final String name = student['name'] ?? 'Aluno';
          final String status = student['status'];

          if (status == 'paid' || status == 'pending') {
            // Se o Smart Diff estiver ativo, checa se já está correto na catraca
            if (existingUserIds != null && activeRuleUserIds != null) {
              final bool isAlreadyActive = existingUserIds.contains(catracaId) && 
                                           activeRuleUserIds.contains(catracaId);
              if (isAlreadyActive) {
                addedCount++;
                return; // Pula requisição desnecessária!
              }
            }

            // O aluno está em dia, então mandamos ou atualizamos na Catraca
            final res = await addUser(ip: ip, id: catracaId, name: name);
            if (res['success'] == true) addedCount++;
          } else if (status == 'overdue') {
            // Se o Smart Diff estiver ativo, checa se já está bloqueado na catraca
            if (activeRuleUserIds != null) {
              final bool isAlreadyBlocked = !activeRuleUserIds.contains(catracaId);
              if (isAlreadyBlocked) {
                removedCount++;
                return; // Pula requisição desnecessária!
              }
            }

            // O aluno está devendo, removemos ele da Catraca (bloqueia o acesso fisicamente)
            final res = await removeUser(ip: ip, id: catracaId);
            if (res['success'] == true) removedCount++;
          }
        }));
      }

      return {
        'success': true,
        'message':
            'Sincronização OK! $addedCount liberados, $removedCount bloqueados / removidos.'
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro na sincronização: $e'};
    }
  }

  /// Fase 2: Gatilho de Sincronização Transparente (Real-time).
  /// Deve ser chamado em background ao cadastrar um aluno ou registrar um pagamento.
  /// Ele roda silenciosamente. Se o PC estiver na rede da catraca (Recepção), ele executa.
  /// Se o acesso for via 4G ou Nutricionista em casa, simplesmente falha no log e ignora o erro.
  /// Sincroniza um aluno específico em tempo real.
  /// userUuid: ID do aluno
  /// forcedStatus: Se já tivermos o status calculado (ex: via Realtime payload), passamos aqui para evitar query.
  static Future<void> syncStudentRealtime(String userUuid,
      {String? forcedStatus, bool? forcedIsBlocked, String? forcedName}) async {
    try {
      if (userUuid.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('control_id_ip');

      if (savedIp == null || savedIp.isEmpty) {
        return; // Módulo Desktop/Catraca não configurado neste dispositivo
      }

      String status = (forcedStatus ?? 'unknown').toLowerCase().trim();
      String name = forcedName ?? 'Aluno';
      bool isBlocked = forcedIsBlocked ?? false;

      // Se não temos o nome, o status ou o bloqueio forçados, buscamos no banco para evitar "renomear" para Aluno
      if (forcedName == null ||
          status == 'unknown' ||
          status == 'pending' ||
          status == 'desconhecido' ||
          forcedIsBlocked == null) {
        print(
            '🔍 [Control iD] Dados incompletos. Realizando checagem manual para $userUuid...');
        final check = await FinancialService.checkStudentStatus(userUuid);
        status = (check['status'] ?? 'unknown').toString().toLowerCase();
        isBlocked = check['is_blocked'] == true;
        if (check['name'] != null) name = check['name'];
        print(
            '📊 [Control iD] Nome: $name | Status: $status | Bloqueado: $isBlocked');
      }

      final int catracaId = generateCatracaId(userUuid);
      print(
          '📊 [Control iD] Aluno: $userUuid | Status: $status | ID Catraca: $catracaId');

      // PRIORIDADE 1: Bloqueio Manual
      if (isBlocked) {
        final res = await removeUser(ip: savedIp, id: catracaId);
        print(
            '🚫 [Control iD] Sinc real-time (BLOQUEIO MANUAL): ${res['message']}');
        return;
      }

      // PRIORIDADE 2: Inadimplência
      if (status == 'paid' || status == 'pending' || status == 'pago') {
        final res = await addUser(ip: savedIp, id: catracaId, name: name);
        print('✅ [Control iD] Sinc real-time (Liberar): ${res['message']}');
      } else if (status == 'overdue' ||
          status == 'vencido' ||
          status == 'atrasado') {
        final res = await removeUser(ip: savedIp, id: catracaId);
        print(
            '🚫 [Control iD] Sinc real-time (Bloquear Inadimplente): ${res['message']}');
      }
    } catch (e) {
      print('⚠️ [Control iD] Erro na sincronização real-time ($e)');
    }
  }

  /// Libera a catraca imediatamente (Abre a porta)
  /// Simula a identificação de um usuário com acesso livre (ID 0)
  static Future<Map<String, dynamic>> release(String ip) async {
    try {
      final sanitizedIp = sanitizeIp(ip);
      String session = await _login(sanitizedIp);
      if (session.isEmpty) throw 'Falha ao autenticar na catraca';

      // ESTRATÉGIA PURE RELAY PULSE (V2.2.2):
      // Foco total em evitar o erro 400 e simular o comando elétrico do menu "Abertura de Porta".

      // 1. HARDWARE PULSE (Muscle): Comando minimalista aceito por 100% dos modelos Control iD.
      // Disparamos o Relé 1 e Relé 2 em sequência com a sintaxe padrão de fábrica.
      final executeUrl = Uri.parse(
          'http://$sanitizedIp/execute_actions.fcgi?session=$session');

      // Tentativa 1: Relé 1 (Porta 1)
      await http.post(
        executeUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "actions": [
            {"action": "door", "parameters": "door=1"}
          ]
        }),
      );

      // Tentativa 2: Relé 2 (Porta 2 - Comum em iDBlock com solenóide invertido)
      await http.post(
        executeUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "actions": [
            {"action": "door", "parameters": "door=2"}
          ]
        }),
      );

      // Tentativa 3: Giro (Catra)
      await http.post(
        executeUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "actions": [
            {"action": "catra", "parameters": "allow=3"}
          ]
        }),
      );

      // 2. VISUAL AUTHORIZATION (Brain): Apenas para feedback no visor, sem campos extras.
      final visualUrl = Uri.parse(
          'http://$sanitizedIp/remote_user_authorization.fcgi?session=$session');
      final visualBody = jsonEncode({
        "event": 7, // Sucesso
        "user_id": 1, // Administrador
        "user_name": "ADMINISTRADOR",
        "user_image": false,
        "portal_id": 1,
        "actions": [
          {"action": "door", "parameters": "door=1"}
        ]
      });

      final response = await http.post(
        visualUrl,
        headers: {'Content-Type': 'application/json'},
        body: visualBody,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Comando de liberação enviado!'};
      } else {
        return {
          'success': false,
          'message': 'Erro da catraca: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// Sincroniza todos os alunos sem exibir popups ou mensagens
  /// Chamado automaticamente ao iniciar o dashboard pelo Admin
  static Future<void> syncAllStudentsSilently() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('control_id_ip');

      if (savedIp == null || savedIp.isEmpty) {
        return; // Módulo Desktop/Catraca não configurado neste dispositivo
      }

      print(
          '🔄 [Control iD] Iniciando sincronização silenciosa de inicialização do sistema...');
      await syncAllStudents(savedIp);
      print('✅ [Control iD] Sincronização silenciosa concluída.');
    } catch (e) {
      print('⚠️ [Control iD] Sincronização silenciosa falhou: $e');
    }
  }

  /// Inicia listeners Realtime PERSISTENTES para sincronização da catraca.
  /// Funciona como singleton: uma vez iniciado, sobrevive à troca de telas.
  /// Deve ser chamado apenas no Windows Desktop (o caller verifica isso).
  static void startPersistentRealtimeSync() {
    if (_realtimeActive) return; // Já está rodando — evita duplicatas
    _realtimeActive = true;

    print('🔄 [Control iD] Iniciando Realtime PERSISTENTE para catraca...');

    // Listener 1: Mudanças na tabela de alunos (status, bloqueio, nome)
    _persistentAlunosChannel = Supabase.instance.client
        .channel('control_id:users_alunos:persistent')
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'users_alunos',
            callback: (payload) async {
              await Future.delayed(const Duration(milliseconds: 1000));

              final newRecord = payload.newRecord;
              if (newRecord.containsKey('id')) {
                final status = newRecord['status_financeiro'] as String?;
                final isBlocked = newRecord['is_blocked'] == true;
                final name = newRecord['nome'] as String?;
                syncStudentRealtime(
                  newRecord['id'],
                  forcedStatus: status,
                  forcedIsBlocked: isBlocked,
                  forcedName: name,
                );
              }
            })
        .subscribe();

    // Listener 2: Mudanças na tabela financeira (pagamentos, estornos)
    _persistentFinancialChannel = Supabase.instance.client
        .channel('control_id:financial_transactions:persistent')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'financial_transactions',
            callback: (payload) async {
              await Future.delayed(const Duration(milliseconds: 1000));

              final record = payload.newRecord.isNotEmpty
                  ? payload.newRecord
                  : payload.oldRecord;

              if (record.containsKey('related_user_id')) {
                syncStudentRealtime(record['related_user_id']);
              } else if (payload.eventType == PostgresChangeEvent.delete) {
                syncAllStudentsSilently();
              }
            })
        .subscribe();

    print('✅ [Control iD] Realtime PERSISTENTE ativo — sobrevive à troca de telas.');
  }

  /// Para os listeners Realtime persistentes (chamado no logout)
  static void stopPersistentRealtimeSync() {
    _persistentAlunosChannel?.unsubscribe();
    _persistentFinancialChannel?.unsubscribe();
    _persistentAlunosChannel = null;
    _persistentFinancialChannel = null;
    _realtimeActive = false;
    print('🛑 [Control iD] Realtime persistente encerrado.');
  }

  /// Busca os logs de acesso da catraca (Modo Estável - 30 registros)
  static Future<List<Map<String, dynamic>>> getAccessLogs(String ip) async {
    try {
      final sanitizedIp = sanitizeIp(ip);
      String session = await _login(sanitizedIp);
      if (session.isEmpty) return [];

      final url =
          Uri.parse('http://$sanitizedIp/load_objects.fcgi?session=$session');

      final body = jsonEncode({
        "object": "access_logs",
        "order": ["id DESC"],
        "limit": 30
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List? logsJson = data['access_logs'] ?? data['values'];
        if (logsJson != null) {
          return List<Map<String, dynamic>>.from(logsJson);
        }
      } else if (response.statusCode == 401) {
        _session = null; // Forza novo login na próxima tentativa
      }
    } catch (e) {
      print('🚨 [ControlIdService] Erro na busca de logs: $e');
    }
    return [];
  }
}
