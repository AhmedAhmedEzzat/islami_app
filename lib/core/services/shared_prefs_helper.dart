import 'package:flutter/foundation.dart';
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
    return _typed(key, () => _preferences.getInt(key));
  }

  static String? getString(String key) {
    if (!isReady) return null;
    return _typed(key, () => _preferences.getString(key));
  }

  static bool? getBool(String key) {
    if (!isReady) return null;
    return _typed(key, () => _preferences.getBool(key));
  }

  static double? getDouble(String key) {
    if (!isReady) return null;
    return _typed(key, () => _preferences.getDouble(key));
  }

  static List<String>? getStringList(String key) {
    if (!isReady) return null;
    return _typed(key, () => _preferences.getStringList(key));
  }

  /// A value of another type than asked for (a damaged or hand-edited
  /// backup, or a key that changed type between versions) reads as absent
  /// rather than throwing, which at start-up would stop the app opening.
  static T? _typed<T>(String key, T? Function() read) {
    try {
      return read();
    } on TypeError {
      debugPrint('Ignoring $key: stored with another type');
      return null;
    }
  }

  /// Every stored key, for backups.
  static Set<String> keys() => isReady ? _preferences.getKeys() : <String>{};

  /// The value stored under [key], whatever its type.
  static Object? getRaw(String key) => isReady ? _preferences.get(key) : null;

  /// Stores [value] (an int, double, bool, String or `List<String>`) under [key].
  static Future<bool> setRaw(String key, Object value) async {
    if (!isReady) return false;
    return switch (value) {
      final int v => _preferences.setInt(key, v),
      final double v => _preferences.setDouble(key, v),
      final bool v => _preferences.setBool(key, v),
      final String v => _preferences.setString(key, v),
      final List<String> v => _preferences.setStringList(key, v),
      _ => false,
    };
  }

  static Future<void> remove(List<String> keys) async {
    if (!isReady) return;
    for (final key in keys) {
      await _preferences.remove(key);
    }
  }
}
