import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Faz upload da foto para o bucket 'profiles' e retorna a URL pública
  static Future<String?> uploadProfilePhoto(File file, String userId) async {
    try {
      final fileExt = file.path.split('.').last;
      final fileName =
          '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // Upload to 'profiles' bucket
      // Nota: O bucket 'profiles' deve existir no Supabase e ser público
      await _client.storage.from('profiles').upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get Public URL
      final imageUrl = _client.storage.from('profiles').getPublicUrl(fileName);
      return imageUrl;
    } catch (e) {
      print('Erro ao fazer upload da foto: $e');
      return null;
    }
  }

  /// Atualiza a URL da foto na tabela correta baseada na role
  static Future<bool> updatePhotoUrl(
      String userId, String role, String url) async {
    try {
      String table;
      // Mapeamento das roles conforme retornado pelo AuthService
      switch (role) {
        case 'admin':
          table = 'users_adm';
          break;
        case 'trainer':
          table = 'users_personal';
          break;
        case 'nutritionist':
          table = 'users_nutricionista';
          break;
        case 'student':
          table = 'users_alunos';
          break;
        default:
          return false;
      }

      await _client.from(table).update({'photo_url': url}).eq('id', userId);
      return true;
    } catch (e) {
      print('Erro ao atualizar URL da foto no banco: $e');
      return false;
    }
  }
}
