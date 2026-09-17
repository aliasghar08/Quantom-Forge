import 'dart:convert';
import 'dart:io';

/// A simple, dependency-free key-value store using a local JSON file.
/// Replaces `shared_preferences`.
class LocalPrefs {
  static LocalPrefs? _instance;
  final Map<String, dynamic> _data;
  final File _file;

  LocalPrefs._(this._data, this._file);

  /// Get the singleton instance.
  static Future<LocalPrefs> getInstance() async {
    if (_instance != null) return _instance!;

    // Find the app data directory. 
    // Note: For this zero-dependency refactor, we are focusing on Windows.
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null) {
      throw UnsupportedError('Only Windows is supported for zero-dependency LocalPrefs');
    }
    
    final dir = Directory('$localAppData\\ColabReactionApp\\Prefs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    final file = File('${dir.path}\\prefs.json');
    Map<String, dynamic> data = {};
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        data = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        // Corrupted prefs, ignore
      }
    }
    
    _instance = LocalPrefs._(data, file);
    return _instance!;
  }

  String? getString(String key) => _data[key] as String?;
  int? getInt(String key) => _data[key] as int?;
  double? getDouble(String key) => _data[key] as double?;
  bool? getBool(String key) => _data[key] as bool?;
  
  bool containsKey(String key) => _data.containsKey(key);

  Future<void> setString(String key, String value) => _setValue(key, value);
  Future<void> setInt(String key, int value) => _setValue(key, value);
  Future<void> setDouble(String key, double value) => _setValue(key, value);
  Future<void> setBool(String key, bool value) => _setValue(key, value);

  Future<void> _setValue(String key, dynamic value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> remove(String key) async {
    _data.remove(key);
    await _save();
  }

  Future<void> _save() async {
    await _file.writeAsString(jsonEncode(_data));
  }
}
