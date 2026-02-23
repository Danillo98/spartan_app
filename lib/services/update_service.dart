import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';

class UpdateService {
  static const String _versionFileName = 'version.json';
  static final String _remoteVersionUrl =
      '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/downloads/$_versionFileName';

  /// Verifica se há uma nova versão disponível
  static Future<Map<String, dynamic>?> checkForUpdates() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return null;

    try {
      final response = await http.get(Uri.parse(_remoteVersionUrl));
      if (response.statusCode != 200) return null;

      final remoteData = jsonDecode(response.body);
      final remoteVersion = remoteData['version'] as String;
      final remoteUrl = remoteData['url'] as String;

      // Tentar obter a versão local primeiro pelo version.json, senão pelo PackageInfo
      String localVersion = '';
      try {
        final exePath = Platform.resolvedExecutable;
        final appDir = File(exePath).parent.path;
        final localVersionFile = File('$appDir\\version.json');

        if (await localVersionFile.exists()) {
          final localData = jsonDecode(await localVersionFile.readAsString());
          localVersion = localData['version'] ?? '';
        }
      } catch (e) {
        print(
            'ℹ️ [UpdateService] version.json local não encontrado ou inválido.');
      }

      if (localVersion.isEmpty) {
        final packageInfo = await PackageInfo.fromPlatform();
        localVersion = packageInfo.version;
      }

      if (_isNewer(remoteVersion, localVersion)) {
        return {
          'version': remoteVersion,
          'url': remoteUrl,
          'notes': remoteData['notes'] ?? '',
        };
      }
    } catch (e) {
      print('⚠️ [UpdateService] Erro ao verificar atualizações: $e');
    }
    return null;
  }

  static bool _isNewer(String remote, String local) {
    if (remote.trim() == local.trim()) return false;

    List<int> remoteParts = remote.split('.').map(int.parse).toList();
    List<int> localParts = local.split('.').map(int.parse).toList();

    for (var i = 0; i < remoteParts.length; i++) {
      if (i >= localParts.length) return true;
      if (remoteParts[i] > localParts[i]) return true;
      if (remoteParts[i] < localParts[i]) return false;
    }
    return false;
  }

  /// Inicia o processo de atualização
  static Future<void> performUpdate(String downloadUrl) async {
    try {
      final tempDir = Directory.systemTemp.path;
      final zipPath = '$tempDir\\spartan_update.zip';
      final scriptPath = '$tempDir\\spartan_updater.ps1';

      // 1. Download do ZIP
      print('📂 [UpdateService] Baixando atualização...');
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) throw 'Falha no download da atualização';
      await File(zipPath).writeAsBytes(response.bodyBytes);

      // 2. Criar script PowerShell de atualização
      final appPath = Platform.resolvedExecutable;
      final appDir = File(appPath).parent.path;
      final exeName = appPath.split('\\').last;

      // Usando r''' para evitar interpolação do Dart e manter os $ literais para o PowerShell
      // Exceto onde precisamos interpolar variáveis do Dart, usamos a concatenação ou string normal.
      final psScript = '''
# Script de Atualização Spartan Desktop
Start-Sleep -Seconds 2
Write-Host "Iniciando atualização do Spartan Desktop..." -ForegroundColor Cyan

\$zipFile = "$zipPath"
\$destDir = "$appDir"
\$exeName = "$exeName"

# Aguarda o processo fechar totalmente
while (Get-Process | Where-Object { \$_.Path -eq "\$destDir\\\$exeName" }) {
    Write-Host "Aguardando encerramento do app..."
    Start-Sleep -Seconds 1
}

# Extrai e substitui
try {
    Write-Host "Extraindo arquivos para \$destDir..." -ForegroundColor Yellow
    Expand-Archive -Path \$zipFile -DestinationPath "\$destDir" -Force
    Write-Host "Sucesso! Reiniciando aplicativo..." -ForegroundColor Green
    Start-Process -FilePath "\$destDir\\\$exeName"
} catch {
    Write-Error "Falha ao extrair atualização: \$_"
    Read-Host "Pressione Enter para fechar"
}
''';

      await File(scriptPath).writeAsString(psScript);

      // 3. Executar o script em uma nova janela (Powershell)
      print('🚀 [UpdateService] Disparando script de atualização...');
      await Process.start(
        'powershell.exe',
        ['-ExecutionPolicy', 'Bypass', '-File', scriptPath],
        runInShell: true,
        mode: ProcessStartMode.detached,
      );

      // 4. Fechar o App atual
      exit(0);
    } catch (e) {
      print('❌ [UpdateService] Erro crítico na atualização: $e');
      rethrow;
    }
  }
}
