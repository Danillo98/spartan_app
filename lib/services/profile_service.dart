import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:typed_data';

class ProfileService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Upload de foto de perfil (compatível com Web e Mobile)
  static Future<String?> uploadProfilePhoto(
    XFile file,
    String userId,
  ) async {
    try {
      // 1. Ler bytes originais
      Uint8List bytes = await file.readAsBytes();
      final fileName = file.name;
      final extension = fileName.split('.').last.toLowerCase();

      print('📸 Tamanho original: ${bytes.length} bytes');

      // 2. Compressão (apenas se não for Web, pois flutter_image_compress tem limitações na web nativa)
      // Mas o plugin suporta web via JS se configurado. Vamos tentar comprimir se for grande.
      if (bytes.length > 500 * 1024) {
        print('⚖️ Comprimindo imagem para atingir meta de < 500KB...');

        try {
          final result = await FlutterImageCompress.compressWithList(
            bytes,
            minHeight: 1024,
            minWidth: 1024,
            quality: 85,
            format:
                extension == 'png' ? CompressFormat.png : CompressFormat.jpeg,
          );

          if (result.length < bytes.length) {
            bytes = Uint8List.fromList(result);
            print('✅ Compressão concluída: ${bytes.length} bytes');
          }
        } catch (e) {
          print('⚠️ Falha na compressão (ignorando): $e');
        }
      }

      // Nome único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
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
