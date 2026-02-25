import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;

class PrintService {
  /// Imprime o relatório de forma cross-platform (Web e Windows/Desktop).
  ///
  /// Na versão Web, ele gera um Blob Object URL e passa via Query Parameter.
  /// Na versão Windows (Desktop), ele embute os dados no HTML template
  /// e lança em um arquivo temporário no navegador padrão através do url_launcher.
  static Future<void> printReport({
    required Map<String, dynamic> data,
    required String templateName, // ex: 'print-financial-monthly.html'
    required String localStorageKey, // ex: 'spartan_financial_monthly_print'
  }) async {
    final jsonData = jsonEncode(data);

    if (kIsWeb) {
      // --------- COMPORTAMENTO WEB ---------
      final blob = html.Blob([jsonData], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final baseUrl = html.window.location.origin;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final printUrl = '$baseUrl/$templateName?v=$timestamp&dataUrl=$url';

      html.window.open(printUrl, '_blank');

      Future.delayed(const Duration(seconds: 20), () {
        html.Url.revokeObjectUrl(url);
      });
    } else {
      // --------- COMPORTAMENTO DESKTOP (WINDOWS/LINUX/MAC) ---------
      try {
        final htmlTemplate = await rootBundle.loadString('web/$templateName');
        final String escapedJsonStr = jsonEncode(jsonData);

        // Injetar script no head
        final injection = '''
    <script>
      try {
        const rawJsonStr = $escapedJsonStr; 
        localStorage.setItem('$localStorageKey', rawJsonStr);
      } catch(e) {
        console.error('Error injecting local storage for print:', e);
      }
    </script>
</head>
''';

        // Substituímos fechamento do </head> para injetar
        final finalHtml = htmlTemplate.replaceFirst('</head>', injection);

        // Criar arquivo temporário para ser lido no navegador
        final tempDir = Directory.systemTemp;
        final salt = DateTime.now().millisecondsSinceEpoch;
        final templateCleaned = templateName.replaceAll(
            RegExp(r'[^a-zA-Z0-9_\.]'), '_'); // Sanitizar

        final tempFile = File('${tempDir.path}/${templateCleaned}_$salt.html');
        await tempFile.writeAsString(finalHtml);

        final fileUri = Uri.file(tempFile.path);

        if (await canLaunchUrl(fileUri)) {
          await launchUrl(fileUri);
        } else {
          // Última tentativa de fallback
          final fallbackString =
              'file:///${tempFile.path.replaceAll('\\', '/')}';
          await launchUrl(Uri.parse(fallbackString));
        }
      } catch (e) {
        print('Erro no PrintService Desktop: $e');
        rethrow;
      }
    }
  }
}
