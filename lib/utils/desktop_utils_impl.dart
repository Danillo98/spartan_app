import 'dart:io';

class DesktopUtils {
  static Future<void> createDesktopShortcut(String appName) async {
    if (!Platform.isWindows) return;
    try {
      final executablePath = Platform.resolvedExecutable;

      // Evitar rodar em ambiente de debug do Flutter (onde o exe é flutter_tester ou afins)
      if (!executablePath.toLowerCase().endsWith('.exe') ||
          executablePath.contains('flutter\\bin')) {
        return;
      }

      final String userProfile = Platform.environment['USERPROFILE'] ?? '';
      if (userProfile.isEmpty) return;

      final String shortcutPath = '$userProfile\\Desktop\\$appName.lnk';
      final file = File(shortcutPath);
      if (await file.exists()) return; // Já existe, não faz nada

      final String script = '''
\$WshShell = New-Object -comObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut("$shortcutPath")
\$Shortcut.TargetPath = "$executablePath"
\$Shortcut.WorkingDirectory = "\$(Split-Path -Path '$executablePath' -Parent)"
\$Shortcut.IconLocation = "$executablePath, 0"
\$Shortcut.Save()
''';
      await Process.run(
          'powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
    } catch (e) {
      print('Erro ao criar atalho no desktop: $e');
    }
  }
}
