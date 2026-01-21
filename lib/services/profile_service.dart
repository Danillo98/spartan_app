import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Upload de foto de perfil (compatível com Web e Mobile)
  static Future<String?> uploadProfilePhoto(
    XFile file,
    String userId,
  ) async {
    try {
      // Ler bytes do arquivo (funciona em web e mobile)
      final bytes = await file.readAsBytes();
      final fileName = file.name;

      // Nome único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final path = 'profile_photos/${userId}_$timestamp.$extension';

      print('📤 Iniciando upload: $path (${bytes.length} bytes)');

      // Upload para o Supabase Storage
      await _client.storage.from('profiles').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: _getContentType(extension),
            ),
          );

      print('✅ Upload concluído');

      // Retornar URL pública
      final url = _client.storage.from('profiles').getPublicUrl(path);
      print('🔗 URL gerada: $url');

      return url;
    } catch (e, stackTrace) {
      print('❌ Erro ao fazer upload da foto: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Determinar content type baseado na extensão
  static String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Atualizar URL da foto no banco de dados
  static Future<bool> updatePhotoUrl(
    String userId,
    String role,
    String photoUrl,
  ) async {
    try {
      String tableName;
      switch (role) {
        case 'admin':
          tableName = 'users_adm';
          break;
        case 'nutritionist':
          tableName = 'users_nutricionista';
          break;
        case 'trainer':
          tableName = 'users_personal';
          break;
        case 'student':
          tableName = 'users_alunos';
          break;
        default:
          throw Exception('Role inválido: $role');
      }

      await _client.from(tableName).update({
        'photo_url': photoUrl,
      }).eq('id', userId);

      return true;
    } catch (e) {
      print('Erro ao atualizar URL da foto: $e');
      return false;
    }
  }

  /// Deletar foto de perfil
  static Future<bool> deleteProfilePhoto(String photoUrl) async {
    try {
      // Extrair o path da URL
      final uri = Uri.parse(photoUrl);
      final path = uri.pathSegments.last;

      await _client.storage.from('profiles').remove([path]);
      return true;
    } catch (e) {
      print('Erro ao deletar foto: $e');
      return false;
    }
  }
}
