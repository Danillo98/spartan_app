import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UpdateService {
  static const String _zipUrl =
      'https://waczgosbsrorcibwfayv.supabase.co/storage/v1/object/public/updates/Spartan_Desktop.zip';

  /// Realiza o download e inicia o script de atualização relay
  static Future<void> performUpdate(Function(double) onProgress) async {
    if (kIsWeb || !Platform.isWindows) return;

    try {
      final tempDir = Directory.systemTemp.path;
      final zipPath = '$tempDir\\Spartan_Update.zip';
      final exePath = Platform.resolvedExecutable;
      final appDir = File(exePath).parent.path;

      print('🚀 Iniciando download da atualização...');

      // 1. Download do ZIP
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(_zipUrl));
      final response = await client.send(request);

      final contentLength = response.contentLength ?? 0;
      int downloadedBytes = 0;

      final file = File(zipPath);
      final sink = file.openWrite();

      await for (var chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength > 0) {
          onProgress(downloadedBytes / contentLength);
        }
      }

      await sink.close();
      client.close();

      print('📦 Download concluído. Gerando script de relay...');

      // 2. Gerar Script BAT de Atualização
      final batchPath = '$tempDir\\spartan_updater.bat';

      final batchContent = '''
@echo off
title Atualizando Spartan Desktop...
echo ===========================================
echo INICIANDO ATUALIZACAO SPARTAN
echo ===========================================

echo [1/4] Forcando encerramento do app...
taskkill /F /IM "Spartan Desktop.exe" /T > nul 2>&1
timeout /t 3 /nobreak > nul

echo [2/4] Extraindo novos arquivos...
if exist "$tempDir\\Spartan_Extraction" rd /s /q "$tempDir\\Spartan_Extraction"
powershell -Command "Expand-Archive -Path '$zipPath' -DestinationPath '$tempDir\\Spartan_Extraction' -Force"

echo [3/4] Substituindo arquivos (Cirurgico)...
if not exist "$tempDir\\Spartan_Extraction\\Spartan_Desktop" (
    echo ERRO: Pasta Spartan_Desktop nao encontrada no ZIP!
    pause
    exit
)

xcopy /s /e /y "$tempDir\\Spartan_Extraction\\Spartan_Desktop\\*" "$appDir"

echo [4/4] Limpando temporarios...
rd /s /q "$tempDir\\Spartan_Extraction"
del "$zipPath"

echo ===========================================
echo ATUALIZACAO CONCLUIDA! REINICIANDO...
echo ===========================================
start "" "$exePath"
exit
''';

      await File(batchPath).writeAsString(batchContent);

      // 3. Executar o BAT e encerrar o App imediatamente
      print('⚡ Executando script e reiniciando...');
      await Process.start('cmd.exe', ['/c', 'start', '""', batchPath],
          runInShell: true);
      exit(0);
    } catch (e) {
      print('❌ Erro no UpdateService: $e');
      rethrow;
    }
  }
}
