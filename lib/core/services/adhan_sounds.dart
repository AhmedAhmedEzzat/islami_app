import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/muezzins.dart';

/// Choosing the user's own adhan recording (MainActivity's AdhanSounds).
abstract final class AdhanSounds {
  static const MethodChannel _channel = MethodChannel('sakina/sounds');

  /// Only Android lets an app give a notification a sound of the user's.
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// One of the phone's own sounds, from the system picker; null if cancelled.
  static Future<CustomSound?> pickSystem({String? current}) => _pick('pickSystem', {'current': ?current});

  /// Any audio file, copied into the phone's Notifications folder so the
  /// system may play it; null if cancelled. Android 10 or later.
  static Future<CustomSound?> pickFile() => _pick('pickFile', const {});

  static Future<bool> canPickFile() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('canPickFile') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Whether [uri] can still be read. True when it cannot be checked (the
  /// background task has no activity), so a recording is never dropped on a
  /// guess.
  static Future<bool> exists(String uri) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('exists', {'uri': uri}) ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  static Future<CustomSound?> _pick(String method, Map<String, Object> args) async {
    if (!supported) return null;
    final picked = await _channel.invokeMapMethod<String, Object?>(method, args);
    return picked == null ? null : CustomSound.fromJson(picked);
  }
}
