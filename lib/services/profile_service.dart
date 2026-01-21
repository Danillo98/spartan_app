import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Upload de foto de perfil (compatível com Web e Mobile)
  static Future<String?> uploadProfilePhoto(
    dynamic file,
    String userId,
  ) async {
    try {
      Uint8List bytes;
      String fileName;

      // Se for Web, file é XFile
      if (kIsWeb) {
        final XFile xFile = file as XFile;
        bytes = await xFile.readAsBytes();
        fileName = xFile.name;
      } else {
        // Mobile: file é File
        final File ioFile = file as File;
        bytes = await ioFile.readAsBytes();
        fileName = ioFile.path.split('/').last;
      }

      // Nome único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'profile_photos/$userId\_$timestamp\_$fileName';

      // Upload para o Supabase Storage
      await _client.storage.from('profiles').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      // Retornar URL pública
      final url = _client.storage.from('profiles').getPublicUrl(path);
      return url;
    } catch (e) {
      print('Erro ao fazer upload da foto: $e');
      return null;
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
