import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'financial_service.dart';

class ControlIdService {
  static Future<Map<String, dynamic>> addUser({
    required String ip,
    required int id,
    required String name,
  }) async {
    try {
      String session = await _login(ip);
      if (session.isEmpty) throw 'Falha de login';

      final urlCreate =
          Uri.parse('http://$ip/create_objects.fcgi?session=$session');
      final urlModify =
          Uri.parse('http://$ip/modify_objects.fcgi?session=$session');

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
      // Tenta login como ping
      final session = await _login(ip);
      return session.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Ativa a câmera da Catraca para cadastrar o rosto de um aluno específico remotamente
  static Future<Map<String, dynamic>> enrollFaceRemote({
    required String ip,
    required int id,
  }) async {
    try {
      String session = await _login(ip);
      if (session.isEmpty) throw 'Falha ao autenticar na catraca';

      final urlWithSession =
          Uri.parse('http://$ip/remote_enroll.fcgi?session=$session');

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
      String session = await _login(ip);
      final urlWithSession =
          Uri.parse('http://$ip/destroy_objects.fcgi?session=$session');

      // Deleta unicamente a REGRA DE ACESSO do ID do usuário.
      // O usuário físico continua na memória da catraca, mas a porta não abre mais.
      final body = jsonEncode({
        "object": "user_access_rules",
        "where": {
          "user_access_rules": {"user_id": id}
        }
      });

      await http.post(
        urlWithSession,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      return {
        'success': true,
        'message': 'Usuário bloqueado com sucesso (Biometria mantida).'
      };
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
  static Future<void> syncStudentRealtime(String userUuid) async {
    try {
      if (userUuid.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('control_id_ip');

      if (savedIp == null || savedIp.isEmpty) {
        return; // Módulo Desktop/Catraca não configurado neste dispositivo
      }

      print(
          '🌐 [Control iD] Analisando status do aluno $userUuid e avisando a Catraca...');

      final now = DateTime.now();
      // Puxa o painel financeiro geral (Contém as regras de cobrança Ledger)
      final studentsStatus = await FinancialService.getMonthlyPaymentsStatus(
          month: now.month, year: now.year);

      // Localiza apenas o aluno alvo
      final studentMap = studentsStatus.firstWhere(
        (s) => s['id'] == userUuid,
        orElse: () => <String, dynamic>{}, // Vazio se não achar
      );

      if (studentMap.isEmpty) {
        print(
            '⚠️ [Control iD] Aluno não encontrado na base financeira. Ignorando.');
        return;
      }

      final int catracaId = generateCatracaId(userUuid);
      final String name = studentMap['name'] ?? 'Aluno';
      final String status = studentMap['status'];

      if (status == 'paid' || status == 'pending') {
        final res = await addUser(ip: savedIp, id: catracaId, name: name);
        print('✅ [Control iD] Sinc real-time (Liberar): ${res['message']}');
      } else if (status == 'overdue') {
        final res = await removeUser(ip: savedIp, id: catracaId);
        print('🚫 [Control iD] Sinc real-time (Bloquear): ${res['message']}');
      }
    } catch (e) {
      print(
          '⚠️ [Control iD] Ignorado: Dispositivo possivelmente fora da rede local ($e)');
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
}
