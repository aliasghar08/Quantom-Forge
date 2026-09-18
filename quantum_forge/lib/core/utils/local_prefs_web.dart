class LocalPrefs {
  static LocalPrefs? _instance;
  final Map<String, dynamic> _data = {};

  LocalPrefs._();

  static Future<LocalPrefs> getInstance() async {
    _instance ??= LocalPrefs._();
    return _instance!;
  }

  String? getString(String key) => _data[key] as String?;
  int? getInt(String key) => _data[key] as int?;
  double? getDouble(String key) => _data[key] as double?;
  bool? getBool(String key) => _data[key] as bool?;
  
  bool containsKey(String key) => _data.containsKey(key);

  Future<void> setString(String key, String value) async => _data[key] = value;
  Future<void> setInt(String key, int value) async => _data[key] = value;
  Future<void> setDouble(String key, double value) async => _data[key] = value;
  Future<void> setBool(String key, bool value) async => _data[key] = value;

  Future<void> remove(String key) async => _data.remove(key);
}
