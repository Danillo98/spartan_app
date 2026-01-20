import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static SupabaseClient? _client;

  // Inicializa o Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }

  // Getter para acessar o cliente do Supabase
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
          'Supabase não foi inicializado. Chame SupabaseService.initialize() primeiro.');
    }
    return _client!;
  }

  // Método auxiliar para verificar se está conectado
  static bool get isInitialized => _client != null;
}
