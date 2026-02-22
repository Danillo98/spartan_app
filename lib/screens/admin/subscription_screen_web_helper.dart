// Web-specific implementation using dart:html
import 'dart:async';
import 'package:universal_html/html.dart' as html;

/// Returns a stream that emits events when the window gains focus
Stream<void> onWindowFocus() {
  return html.window.onFocus.map((_) {});
}
