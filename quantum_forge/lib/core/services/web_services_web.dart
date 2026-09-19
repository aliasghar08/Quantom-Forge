// Browser implementation of the services declared in `web_services.dart`.
//
// Uses the same `dart:js_interop` bindings the app previously kept in
// `web_bindings.dart`, plus a promise-to-Future bridge for `window.fetch`.
//
// Type checks use the `isA` / `typeofEquals` helpers rather than Dart `is`:
// runtime casts between JS interop types are not platform-consistent and the
// analyzer rejects them (`invalid_runtime_check_with_js_interop_types`).
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get _window;

/// Minimal typed view of `window.localStorage`, kept for callers that need raw
/// browser storage rather than `shared_preferences`.
@JS('window.localStorage')
external Storage get _localStorage;

@JS()
@staticInterop
class Storage {}

extension StorageExt on Storage {
  @JS('getItem')
  external JSString? _getItem(JSString key);

  @JS('setItem')
  external void _setItem(JSString key, JSString value);

  @JS('removeItem')
  external void _removeItem(JSString key);

  String? getItem(String key) => _getItem(key.toJS)?.toDart;
  void setItem(String key, String value) => _setItem(key.toJS, value.toJS);
  void removeItem(String key) => _removeItem(key.toJS);
}

class WebServices {
  const WebServices._();

  /// Performs a GET request and returns the response body as text.
  ///
  /// HTTP failures throw instead of silently handing an error document back to
  /// the caller, which is what the old `fetch` wrapper did.
  static Future<String> fetchString(String url) async {
    final fetchFn = _window.getProperty('fetch'.toJS);
    if (fetchFn == null || !fetchFn.isA<JSFunction>()) {
      throw UnsupportedError('fetch() is unavailable in this browser.');
    }

    final response = await _awaitJs(
      (fetchFn as JSFunction).callAsFunction(_window, url.toJS),
    );
    if (response == null || !response.isA<JSObject>()) {
      throw StateError('fetch() returned nothing for $url');
    }
    final responseObj = response as JSObject;

    final ok = responseObj.getProperty('ok'.toJS);
    if (ok.isA<JSBoolean>() && !(ok as JSBoolean).toDart) {
      final status = responseObj.getProperty('status'.toJS);
      final code = status.isA<JSNumber>() ? (status as JSNumber).toDartInt : 0;
      throw StateError('HTTP $code for $url');
    }

    final textFn = responseObj.getProperty('text'.toJS);
    if (textFn == null || !textFn.isA<JSFunction>()) {
      throw StateError('Response has no text() for $url');
    }
    final text =
        await _awaitJs((textFn as JSFunction).callAsFunction(responseObj));
    if (text == null) return '';
    // `dartify()` converts a JS primitive to its Dart equivalent without a
    // platform-dependent interop cast (a JS string → Dart String).
    final dartified = text.dartify();
    return dartified is String ? dartified : '$dartified';
  }

  /// Opens [url] in a new tab. Returns false when the browser refuses.
  static bool openUrl(String url) {
    final open = _window.getProperty('open'.toJS);
    if (open == null || !open.isA<JSFunction>()) return false;
    (open as JSFunction).callAsFunction(_window, url.toJS, '_blank'.toJS);
    return true;
  }

  /// Raw localStorage access for callers that predate `shared_preferences`.
  static String? getPref(String key) => _localStorage.getItem(key);
  static void setPref(String key, String value) => _localStorage.setItem(key, value);
  static void removePref(String key) => _localStorage.removeItem(key);

  /// Awaits a value that may already be resolved or may be a JS Promise, and
  /// returns it as a [JSAny?]. The previous version only returned JSObjects,
  /// which silently dropped JS *primitives* (strings/numbers/booleans) — so
  /// `Response.text()` came back null and callers tried to `jsonDecode('')`.
  static Future<JSAny?> _awaitJs(JSAny? value) async {
    if (value == null) return null;
    if (value.isA<JSPromise>()) {
      return await (value as JSPromise).toDart;
    }
    return value;
  }
}
