import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_version.dart';
import 'helpers/version_helper_web.dart'
    if (dart.library.io) 'helpers/version_helper_io.dart' as helper;

class VersionService {
  static final _supabase = Supabase.instance.client;

  /// Verifica se há uma atualização obrigatória disponível (V1.0.1 em diante)
  /// Retorna apenas se houver atualização.
  static Future<String?> checkForUpdate() async {
    try {
      final response = await _supabase
          .from('app_versao')
          .select()
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        // Se não tiver versão, assume que é V1.0.0 (antigo) já que a tabela é nova
        return null;
      }

      final remoteVersionStr = response['versao_atual'] as String;

      final currentVer = AppVersion.parseVersion(AppVersion.current);
      final remoteVer = AppVersion.parseVersion(remoteVersionStr);

      if (remoteVer > currentVer) {
        print(
            '🚨 Nova versão detectada: $remoteVersionStr > ${AppVersion.current}');
        return remoteVersionStr;
      }

      print('✅ Versão atualizada: ${AppVersion.current}');
      return null;
    } catch (e) {
      print('⚠️ Erro check update: $e');
      return null;
    }
  }

  static void forceUpdate() {
    helper.forceReload();
  }
}
