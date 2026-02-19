import 'dart:convert';
import 'package:http/http.dart' as http;

class ControlIdService {
  /// Adiciona um usuário na Control iD (Lista Branca)
  /// Retorna true se sucesso
  static Future<Map<String, dynamic>> addUser({
    required String ip,
    required int id,
    required String name,
  }) async {
    try {
      // Endpoint padrão da Control iD
      // Tenta conexão sem autenticação primeiro (padrão de fábrica muitas vezes aceita se session vazia)
      // Ou usa admin:admin

      final url = Uri.parse('http://$ip/add_users.fcgi?session=');

      final body = jsonEncode({
        "users": [
          {
            "id": id,
            "name": name,
            "salt": "0", // Padrão
            "password": "", // Sem senha de teclado
            "begin_time": 0, // 0 = sempre válido
            "end_time": 0, // 0 = sempre válido
          }
        ]
      });

      // Tenta Basic Auth padrão (admin:admin) se precisar
      // Mas muitas vezes a sessão via URL é suficiente se login foi feito, ou cria sessão nova.
      // Vamos tentar login primeiro para garantir.

      String session = await _login(ip);

      final urlWithSession =
          Uri.parse('http://$ip/add_users.fcgi?session=$session');

      final response = await http.post(
        urlWithSession,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Usuário sincronizado'};
      } else {
        return {
          'success': false,
          'message': 'Erro ${response.statusCode}: ${response.body}'
        };
      }
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
}
