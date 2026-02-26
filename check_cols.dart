import 'dart:convert';
import 'package:http/http.dart' as http;

const SUPABASE_URL = 'https://waczgosbsrorcibwfayv.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndhY3pnb3Nic3JvcmNpYndmYXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzOTQzNTgsImV4cCI6MjA4Mzk3MDM1OH0.IkVIseJ0StG6XKmcEpvTVaqCYfSRwVmASOquNQIwz-w';

void main() async {
  final url = Uri.parse('$SUPABASE_URL/rest/v1/users_alunos?select=*&limit=1');
  final response = await http.get(url, headers: {
    'apikey': SUPABASE_KEY,
    'Authorization': 'Bearer $SUPABASE_KEY',
  });

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    if (data.isNotEmpty) {
      print('Colunas em users_alunos:');
      final keys = (data[0] as Map<String, dynamic>).keys.toList();
      keys.sort();
      for (var key in keys) {
        print('- $key');
      }
    } else {
      print('Tabela vazia ou sem registros acessíveis.');
    }
  } else {
    print('Erro: ${response.statusCode} - ${response.body}');
  }
}
