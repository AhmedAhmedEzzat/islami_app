import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'shared_prefs_helper.dart';

/// One good deed on the daily checklist: built in ([builtIn] true, named by
/// the app in the reader's language) or the reader's own.
@immutable
class Deed {
  const Deed(this.id, {this.title = '', this.builtIn = false});

  final String id;
  final String title;
  final bool builtIn;
}

/// The daily checklist of good deeds: which are on it, which were done on
/// each day, and the run of days with all of them done.
abstract final class DailyDeeds {
  /// The built-in deeds, in the order shown. Their names come from l10n.
  static const List<String> builtInIds = ['morningAdhkar', 'eveningAdhkar', 'quran', 'sunnah', 'witr', 'sadaqa'];

  static final ValueNotifier<int> changes = ValueNotifier(0);

  static const String _customKey = 'deeds.custom';
  static const String _hiddenKey = 'deeds.hidden';
  static String _dayKey(DateTime d) => 'deeds.${d.year}-${d.month}-${d.day}';

  static List<String> _strings(String key) {
    final raw = LocalStorageServices.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return [for (final e in jsonDecode(raw) as List) if (e is String) e];
    } catch (_) {
      return [];
    }
  }

  static List<Deed> custom() {
    final raw = LocalStorageServices.getString(_customKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          if (e is Map && e['id'] is String && e['title'] is String) Deed(e['id'] as String, title: e['title'] as String),
      ];
    } catch (_) {
      return [];
    }
  }

  static Set<String> hidden() => _strings(_hiddenKey).toSet();

  /// Every deed, built in first, whether shown or not.
  static List<Deed> all() => [for (final id in builtInIds) Deed(id, builtIn: true), ...custom()];

  /// The deeds on the checklist.
  static List<Deed> visible() {
    final off = hidden();
    return [for (final d in all()) if (!off.contains(d.id)) d];
  }

  static Set<String> doneOn(DateTime day) => _strings(_dayKey(day)).toSet();

  static Future<void> toggle(DateTime day, String id) async {
    final done = doneOn(day);
    done.contains(id) ? done.remove(id) : done.add(id);
    await LocalStorageServices.setString(_dayKey(day), jsonEncode(done.toList()));
    changes.value++;
  }

  static Future<void> setShown(String id, bool shown) async {
    final off = hidden();
    shown ? off.remove(id) : off.add(id);
    await LocalStorageServices.setString(_hiddenKey, jsonEncode(off.toList()));
    changes.value++;
  }

  static Future<void> addCustom(String title, {DateTime? now}) async {
    final text = title.trim();
    if (text.isEmpty) return;
    final list = custom()..add(Deed('c${(now ?? DateTime.now()).microsecondsSinceEpoch}', title: text));
    await _saveCustom(list);
  }

  static Future<void> removeCustom(String id) async {
    await _saveCustom(custom()..removeWhere((d) => d.id == id));
    // Nor kept in the hidden list, which would otherwise only grow.
    await setShown(id, true);
  }

  static Future<void> _saveCustom(List<Deed> list) async {
    await LocalStorageServices.setString(
      _customKey,
      jsonEncode([for (final d in list) {'id': d.id, 'title': d.title}]),
    );
    changes.value++;
  }

  /// Whether every deed on today's list was done on [day].
  static bool allDoneOn(DateTime day, List<Deed> deeds) {
    if (deeds.isEmpty) return false;
    final done = doneOn(day);
    return deeds.every((d) => done.contains(d.id));
  }

  /// Consecutive days with every deed on the list done, counting back from
  /// [today]; an unfinished today does not break a run that reached
  /// yesterday. By calendar date, so clock changes cannot skip a day.
  static int streak(DateTime today) {
    final deeds = visible();
    var day = DateTime(today.year, today.month, today.day);
    if (!allDoneOn(day, deeds)) day = DateTime(day.year, day.month, day.day - 1);
    var n = 0;
    while (allDoneOn(day, deeds) && n < 3650) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }
}
