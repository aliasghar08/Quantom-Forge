// `AppStorage` for the Dart VM — that is, `flutter test`, and any desktop or
// mobile build.
//
// This is a real in-memory store rather than a throwing stub, which is a
// deliberate difference from the other non-web stubs in this folder. Those fail
// loudly because a test that calls `window.fetch` is testing the wrong thing.
// Storage is not like that: "settings survive a round trip through the store" is
// exactly what the settings and theme tests assert, and they can assert it here
// perfectly well. A throwing stub would force every one of those tests to mock
// persistence instead of exercising it.
//
// The map is process-wide, so it behaves like a single browser origin: state
// written by one notifier is visible to the next, which is what the tests need
// to check. It outlives an individual test, so tests that care about a clean
// slate should call `AppStorage.clear()` in `setUp`.
//
// `isPersistent` is false, and that is the truth: nothing here survives the
// process. On the web it reports whether localStorage actually took.
class AppStorage {
  AppStorage._();

  static final Map<String, String> _values = <String, String>{};

  /// Always false off the web — there is no durable store here.
  static bool get isPersistent => false;

  // ── Typed accessors ───────────────────────────────────────────────────────

  static String? getString(String key) => _values[key];

  static void setString(String key, String value) => _values[key] = value;

  static bool? getBool(String key) {
    final raw = _values[key];
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    return null;
  }

  static void setBool(String key, bool value) => _values[key] = value.toString();

  static int? getInt(String key) {
    final raw = _values[key];
    return raw == null ? null : int.tryParse(raw);
  }

  static void setInt(String key, int value) => _values[key] = value.toString();

  static double? getDouble(String key) {
    final raw = _values[key];
    if (raw == null) return null;
    return double.tryParse(raw) ?? int.tryParse(raw)?.toDouble();
  }

  static void setDouble(String key, double value) => _values[key] = '$value';

  static bool containsKey(String key) => _values.containsKey(key);

  static void remove(String key) => _values.remove(key);

  /// Empties the store. Tests call this in `setUp` so state written by one test
  /// cannot leak into the next.
  static void clear() => _values.clear();
}
