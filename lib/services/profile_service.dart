import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:typed_data';

class ProfileService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Upload de foto de perfil (compatível com Web e Mobile)
  /// Upload de foto de perfil (compatível com Web e Mobile)
  static Future<String?> uploadProfilePhoto(
    XFile file,
    String userId,
  ) async {
    try {
      // 1. Ler bytes originais
      Uint8List bytes = await file.readAsBytes();
      // String extensions = 'jpg'; // Removido

      print('📸 Tamanho original: ${bytes.length} bytes');

      // 2. Compressão e Conversão para JPEG
      // Sempre tenta comprimir para garantir < 500KB e formato JPEG
      // Se já for pequeno e JPEG, o compressWithList ainda é útil para normalizar,
      // mas podemos pular se for muito pequeno.
      if (bytes.length > 500 * 1024 ||
          !file.path.toLowerCase().endsWith('.jpg') &&
              !file.path.toLowerCase().endsWith('.jpeg')) {
        print('⚖️ Otimizando imagem (Compressão + Conversão JPEG)...');
        try {
          final result = await FlutterImageCompress.compressWithList(
            bytes,
            minHeight: 1024,
            minWidth: 1024,
            quality: 75, // Qualidade balanceada
            format: CompressFormat.jpeg,
          );
          bytes = Uint8List.fromList(result);
          print('✅ Imagem otimizada: ${bytes.length} bytes');
        } catch (e) {
          print('⚠️ Falha na compressão (usando original): $e');
          // Se falhar compressão mas for PNG, pode gastar muito espaço.
          // Mas mantemos o fluxo para não travar.
        }
      }

      // Nome FIXO para o arquivo: userId.jpg
      // Isso garante que o Supabase SUBSTITUA o arquivo anterior,
      // evitando acúmulo de lixo e economizando espaço no Storage.
      final path = 'profile_photos/$userId.jpg';

      print('📤 Iniciando upload (Overwrite): $path (${bytes.length} bytes)');

      // Upload para o Supabase Storage
      await _client.storage.from('profiles').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true, // Importante: Sobrescreve se existir
              contentType: 'image/jpeg',
            ),
          );

      print('✅ Upload concluído');

      // Retornar URL pública com cache bust AGRESSIVO
      // Como o arquivo é sobrescrito, precisamos MUITO do timestamp na URL
      final baseUrl = _client.storage.from('profiles').getPublicUrl(path);
      final cacheBust = DateTime.now().millisecondsSinceEpoch;
      final url = '$baseUrl?t=$cacheBust&v=3&nocache=true';
      print('🔗 URL gerada com cache bust: $url');

      return url;
    } catch (e, stackTrace) {
      print('❌ Erro ao fazer upload da foto: $e');
      print('Stack trace: $stackTrace');
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
      print('📸 updatePhotoUrl chamado:');
      print('   userId: $userId');
      print('   role: $role');
      print('   photoUrl: $photoUrl');

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

      print('   Tabela: $tableName');

      final response = await _client
          .from(tableName)
          .update({
            'photo_url': photoUrl,
          })
          .eq('id', userId)
          .select();

      print('✅ Atualização bem-sucedida: $response');
      return true;
    } catch (e) {
      print('❌ Erro ao atualizar URL da foto: $e');
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
