import 'dart:io';

void main() async {
  final dir = Directory('lib');
  await for (final file in dir.list(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = await file.readAsString();
      if (content.contains("import 'dart:html' as html;")) {
        final newContent = content.replaceAll(
          "import 'dart:html' as html;",
          "import 'package:universal_html/html.dart' as html;",
        );
        await file.writeAsString(newContent);
        print('Fixed ${file.path}');
      }
    }
  }
}
