import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/prefs_keys.dart';
import 'shared_prefs_helper.dart';

/// What a backup file holds, once read and checked.
@immutable
class BackupFile {
  const BackupFile(this.created, this.entries);

  final DateTime? created;
  final Map<String, Object> entries;
}

/// The reader's own data in one file: bookmarks, notes, memorisation, the
/// prayer log, missed prayers and fasts, good deeds, khatma, tasbeeh and
/// settings, so it can follow them to a new phone.
///
/// It is everything in storage except what belongs to this phone alone:
/// downloaded recitations (the files are not in the backup), chosen adhan
/// recordings (their URIs point into this phone), the home screen widget's
/// cache and the rate-the-app counters.
abstract final class Backup {
  static const String app = 'sakina';
  static const int version = 1;

  static bool _kept(String key) =>
      key != PrefsKeys.widgetPrayers &&
      key != PrefsKeys.customAdhan &&
      key != PrefsKeys.customFajrAdhan &&
      !key.startsWith('recitation.downloads.') &&
      !key.startsWith('review.');

  /// The backup as JSON text.
  static String encode({DateTime? now}) {
    final data = <String, Object>{};
    for (final key in LocalStorageServices.keys().where(_kept).toList()..sort()) {
      final value = LocalStorageServices.getRaw(key);
      final typed = switch (value) {
        final int v => {'i': v},
        final double v => {'d': v},
        final bool v => {'b': v},
        final String v => {'s': v},
        final List<Object?> v => {'l': [for (final e in v) '$e']},
        _ => null,
      };
      if (typed != null) data[key] = typed;
    }
    return const JsonEncoder.withIndent(' ').convert({
      'app': app,
      'version': version,
      'created': (now ?? DateTime.now()).toIso8601String(),
      'data': data,
    });
  }

  /// Reads a backup file, or null if [text] is not one this app can restore.
  static BackupFile? decode(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map || json['app'] != app || json['version'] is! int || (json['version'] as int) > version) {
        return null;
      }
      final data = json['data'];
      if (data is! Map) return null;
      final entries = <String, Object>{};
      for (final MapEntry(:key, :value) in data.entries) {
        if (key is! String || !_kept(key) || value is! Map || value.length != 1) continue;
        final parsed = switch (value.entries.first) {
          MapEntry(key: 'i', value: final int v) => v,
          MapEntry(key: 'd', value: final num v) => v.toDouble(),
          MapEntry(key: 'b', value: final bool v) => v,
          MapEntry(key: 's', value: final String v) => v,
          MapEntry(key: 'l', value: final List<Object?> v) => [for (final e in v) '$e'],
          _ => null,
        };
        if (parsed != null) entries[key] = parsed;
      }
      return BackupFile(DateTime.tryParse(json['created'] as String? ?? ''), entries);
    } on FormatException {
      return null;
    }
  }

  /// Replaces the reader's data with [file]'s. What belongs to this phone
  /// alone is left as it is.
  static Future<void> restore(BackupFile file) async {
    await LocalStorageServices.remove([
      for (final key in LocalStorageServices.keys())
        if (_kept(key)) key,
    ]);
    for (final MapEntry(:key, :value) in file.entries.entries) {
      await LocalStorageServices.setRaw(key, value);
    }
  }
}
