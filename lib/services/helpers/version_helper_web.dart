// Implementação WEB: Usa dart:html para recarregar a página
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void forceReload() {
  // Força reload ignorando cache (true) se possível, ou normal
  html.window.location.reload();
}
