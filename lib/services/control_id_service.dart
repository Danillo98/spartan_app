import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'financial_service.dart';

class ControlIdService {
  // Histórico persistente que sobrevive à mudança de telas (Memória de Sessão)
  static final List<Map<String, dynamic>> accessLogHistory = [];
  static int lastProcessedLogId = 0;

  static void addLogToHistory(Map<String, dynamic> log) {
    if (log['log_id'] != null && log['log_id'] > 0) {
      bool exists = accessLogHistory.any((l) => l['log_id'] == log['log_id']);
      if (exists) return;
      if (log['log_id'] > lastProcessedLogId) {
        lastProcessedLogId = log['log_id'];
      }
    }

    accessLogHistory.insert(0, log);

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
      String session = await _login(sanitizedIp);
      if (session.isEmpty) throw 'Falha de login';

      final urlCreate =
          Uri.parse('http://$sanitizedIp/create_objects.fcgi?session=$session');
      final urlModify =
          Uri.parse('http://$sanitizedIp/modify_objects.fcgi?session=$session');

      // 1. Tenta criar o usuário. Se já existir, tudo bem.
      final createUserBody = jsonEncode({
        "object": "users",
        "values": [
          {
            "id": id,
            "name": name,
            "registration": id.toString(),
            "password": "" // opcional, mas seguro enviar vazio
          }
        ]
      });

      final resCreate = await http.post(
        urlCreate,
        headers: {'Content-Type': 'application/json'},
        body: createUserBody,
      );

      // Se falhar, presumimos que já existe. Usamos modify_objects para manter o nome atualizado.
      if (resCreate.statusCode != 200) {
        final modifyUserBody = jsonEncode({
          "object": "users",
          "values": {"name": name},
          "where": {
            "users": {"id": id}
          }
        });
        await http.post(
          urlModify,
          headers: {'Content-Type': 'application/json'},
          body: modifyUserBody,
        );
      }

      // 2. Criar ou restaurar o vínculo do Usuário com a "Regra de Acesso Sempre Liberado" (Normalmente ID 1)
      // Se ele estava bloqueado, isso reativa ele na catraca física
      final ruleBody = jsonEncode({
        "object": "user_access_rules",
        "values": [
          {
            "user_id": id,
            "access_rule_id": 1 // 1 é a Regra Padrão que vem de fábrica (24h)
          }
        ]
      });

      // Ignoramos o retorno porque se a regra já estiver lá (aluno já liberado), vai retornar erro de duplicata, o que é sucesso para nós.
      await http.post(
        urlCreate,
        headers: {'Content-Type': 'application/json'},
        body: ruleBody,
      );

      return {'success': true, 'message': 'Usuário sincronizado e liberado!'};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// Tenta logar e retornar o session ID
  static Future<String> _login(String ip) async {
    try {
      final url = Uri.parse('http://$ip/login.fcgi');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body:
            jsonEncode({"login": "admin", "password": "admin"}), // Senha padrão
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['session'] ?? '';
      }
    } catch (e) {
      print('Erro login: $e');
    }
    return ''; // Retorna vazio se falhar, tenta sem sessão
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
      String session = await _login(sanitizedIp);
      if (session.isEmpty) throw 'Falha ao autenticar na catraca';

      final urlWithSession = Uri.parse(
          'http://$sanitizedIp/destroy_objects.fcgi?session=$session');

      // Deleta unicamente a REGRA DE ACESSO do ID do usuário.
      // O usuário físico continua na memória da catraca, mas a porta não abre mais.
      final body = jsonEncode({
        "object": "user_access_rules",
        "where": {
          "user_access_rules": {"user_id": id}
        }
      });

      final response = await http.post(
        urlWithSession,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Usuário bloqueado com sucesso (Biometria mantida).'
        };
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

  /// Sincroniza TODOS os alunos da academia atual para a Catraca
  static Future<Map<String, dynamic>> syncAllStudents(String ip) async {
    try {
      final now = DateTime.now();
      // Busca a lista atualizada de alunos e seus status (paid, pending, overdue)
      final studentsStatus = await FinancialService.getMonthlyPaymentsStatus(
          month: now.month, year: now.year);

      int addedCount = 0;
      int removedCount = 0;

      for (var student in studentsStatus) {
        final String uuid = student['id'];
        final int catracaId = generateCatracaId(uuid);
        final String name = student['name'] ?? 'Aluno';
        final String status = student['status'];

        if (status == 'paid' || status == 'pending') {
          // O aluno está em dia, então mandamos ou atualizamos na Catraca
          final res = await addUser(ip: ip, id: catracaId, name: name);
          if (res['success'] == true) addedCount++;
        } else if (status == 'overdue') {
          // O aluno está devendo, removemos ele da Catraca (bloqueia o acesso fisicamente)
          final res = await removeUser(ip: ip, id: catracaId);
          if (res['success'] == true) removedCount++;
        }
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
      {String? forcedStatus, bool? forcedIsBlocked}) async {
    try {
      if (userUuid.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('control_id_ip');

      if (savedIp == null || savedIp.isEmpty) {
        return; // Módulo Desktop/Catraca não configurado neste dispositivo
      }

      String status = (forcedStatus ?? 'unknown').toLowerCase().trim();
      String name = 'Aluno';
      bool isBlocked = forcedIsBlocked ?? false;

      // Se não temos o status ou o bloqueio forçados, buscamos no banco
      if (status == 'unknown' ||
          status == 'pending' ||
          status == 'desconhecido' ||
          forcedIsBlocked == null) {
        print(
            '🔍 [Control iD] Status/Bloqueio incerto. Realizando checagem manual de ledger para $userUuid...');
        final check = await FinancialService.checkStudentStatus(userUuid);
        status = (check['status'] ?? 'unknown').toString().toLowerCase();
        isBlocked = check['is_blocked'] == true;
        if (check['name'] != null) name = check['name'];
        print('📊 [Control iD] Status: $status | Bloqueado Manual: $isBlocked');
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

  /// Busca os logs de acesso da catraca
  static Future<List<Map<String, dynamic>>> getAccessLogs(String ip) async {
    try {
      final sanitizedIp = sanitizeIp(ip);
      String session = await _login(sanitizedIp);
      if (session.isEmpty) return [];

      final url =
          Uri.parse('http://$sanitizedIp/load_objects.fcgi?session=$session');

      final body = jsonEncode({
        "object": "access_logs",
        "order": ["id DESC"], // Mais recentes primeiro
        "limit": 20 // Pegar apenas os últimos 20
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['access_logs'] ?? []);
      }
    } catch (e) {
      print('Erro ao buscar logs da catraca: $e');
    }
    return [];
  }
}
