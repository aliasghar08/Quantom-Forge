// Non-web implementation of the browser services.
//
// `flutter test` runs on the Dart VM, where there is no `window.fetch`. Rather
// than break the compile (which is what the old unconditional `dart:js_interop`
// import did), this stub exists so every screen and provider stays testable;
// calls that genuinely need a browser fail loudly and immediately.
import 'dart:async';

class WebServices {
  const WebServices._();

  static const String unavailable =
      'WebServices.fetchString requires the web build of Quantum Forge.';

  /// Not supported off the web.
  static Future<String> fetchString(String url) =>
      Future<String>.error(UnsupportedError(unavailable));

  /// No browser tab to open; returns false so callers can degrade gracefully.
  static bool openUrl(String url) => false;
}
