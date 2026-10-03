import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalStorageServices {
  static SharedPreferences? _prefs;

  /// True once [init] has run. Reads before that return null and writes are
  /// dropped, so widgets can be pumped in tests without mocking storage.
  static bool get isReady => _prefs != null;

  static SharedPreferences get _preferences => _prefs!;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<bool> setInt(String key, int value) {
    if (!isReady) return Future.value(false);
    return _preferences.setInt(key, value);
  }

  static Future<bool> setString(String key, String value) {
    if (!isReady) return Future.value(false);
    return _preferences.setString(key, value);
  }

  static Future<bool> setBool(String key, bool value) {
    if (!isReady) return Future.value(false);
    return _preferences.setBool(key, value);
  }

  static Future<bool> setDouble(String key, double value) {
    if (!isReady) return Future.value(false);
    return _preferences.setDouble(key, value);
  }

  static Future<bool> setStringList(String key, List<String> value) {
    if (!isReady) return Future.value(false);
    return _preferences.setStringList(key, value);
  }

  static int? getInt(String key) {
    if (!isReady) return null;
    return _preferences.getInt(key);
  }

  static String? getString(String key) {
    if (!isReady) return null;
    return _preferences.getString(key);
  }

  static bool? getBool(String key) {
    if (!isReady) return null;
    return _preferences.getBool(key);
  }

  static double? getDouble(String key) {
    if (!isReady) return null;
    return _preferences.getDouble(key);
  }

  static List<String>? getStringList(String key) {
    if (!isReady) return null;
    return _preferences.getStringList(key);
  }

  static Future<void> remove(List<String> keys) async {
    if (!isReady) return;
    for (final key in keys) {
      await _preferences.remove(key);
    }
  }
}
