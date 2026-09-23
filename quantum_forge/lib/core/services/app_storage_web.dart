// Browser implementation of `AppStorage`, on `window.localStorage`.
//
// localStorage is what survives a refresh and a browser restart, which is the
// whole point: without it, reloading the page loses the theme and every setting.
//
// It is not guaranteed to be *usable*, though. It throws `SecurityError` when
// the page is sandboxed, when third-party storage is blocked, and in some
// private-browsing modes; writes throw `QuotaExceededError` when the origin's
// quota is full. None of those should take the app down, so every operation
// falls back to an in-process map: state stops surviving a refresh, but the
// session keeps working and `isPersistent` says so plainly rather than leaving
// the caller to guess.
//
// The probe runs once, lazily, on first use. Checking the API's presence is not
// enough — a sandboxed iframe exposes `localStorage` and throws only when you
// touch it.
import 'package:web/web.dart' as web;

class AppStorage {
  AppStorage._();

  /// Values used when localStorage is unavailable or a write is rejected.
  static final Map<String, String> _fallback = <String, String>{};

  /// Whether localStorage can actually be written to on this page.
  static final bool _localStorageWorks = _probe();

  /// True when state will survive a refresh.
  ///
  /// False means the app is running against the in-process fallback, so the
  /// caller is looking at a session-only store. Worth surfacing in a diagnostic
  /// rather than discovering when a setting resets.
  static bool get isPersistent => _localStorageWorks;

  static bool _probe() {
    try {
      final store = web.window.localStorage;
      const probeKey = '__quantum_forge_probe__';
      store.setItem(probeKey, '1');
      store.removeItem(probeKey);
      return true;
    } catch (_) {
      // Sandboxed, blocked, or quota already exhausted at startup.
      return false;
    }
  }

  static String? _read(String key) {
    if (!_localStorageWorks) return _fallback[key];
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return _fallback[key];
    }
  }

  static void _write(String key, String value) {
    if (!_localStorageWorks) {
      _fallback[key] = value;
      return;
    }
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {
      // Quota exceeded is the usual cause. Keep the value for this session so
      // the UI does not contradict itself, and let the next read find it.
      _fallback[key] = value;
    }
  }

  static void _delete(String key) {
    _fallback.remove(key);
    if (!_localStorageWorks) return;
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {
      // Nothing useful to do; the fallback entry is already gone.
    }
  }

  // ── Typed accessors ───────────────────────────────────────────────────────

  static String? getString(String key) => _read(key);

  static void setString(String key, String value) => _write(key, value);

  /// `null` when absent, or when the stored text is not a boolean.
  static bool? getBool(String key) {
    final raw = _read(key);
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    return null;
  }

  static void setBool(String key, bool value) => _write(key, value.toString());

  static int? getInt(String key) {
    final raw = _read(key);
    return raw == null ? null : int.tryParse(raw);
  }

  static void setInt(String key, int value) => _write(key, value.toString());

  static double? getDouble(String key) {
    final raw = _read(key);
    if (raw == null) return null;
    // `double.tryParse` rejects the integer-looking text `int` writes produce
    // only for whole values, so handle those too — the app stores temperatures
    // and spring constants through both accessors across versions.
    return double.tryParse(raw) ?? int.tryParse(raw)?.toDouble();
  }

  static void setDouble(String key, double value) => _write(key, '$value');

  static bool containsKey(String key) => _read(key) != null;

  static void remove(String key) => _delete(key);

  /// Removes every entry for this origin.
  ///
  /// Intended for tests and for a "reset workspace" action. It clears the whole
  /// origin, not just this app's keys, because the app owns its origin.
  static void clear() {
    _fallback.clear();
    if (!_localStorageWorks) return;
    try {
      web.window.localStorage.clear();
    } catch (_) {
      // Nothing to do.
    }
  }
}
