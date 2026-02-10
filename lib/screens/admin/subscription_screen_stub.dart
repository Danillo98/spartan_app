// Stub implementation for non-web platforms
import 'dart:async';

/// Returns an empty stream (non-web platforms use WidgetsBindingObserver)
Stream<void> onWindowFocus() {
  return const Stream.empty();
}
