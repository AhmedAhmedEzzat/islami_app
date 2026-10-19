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

  /// Whether the day was a full one, decided against the list as it stood
  /// then, so adding or hiding a deed later does not rewrite past days.
  static String _fullKey(DateTime d) => 'deeds.full.${d.year}-${d.month}-${d.day}';

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
    // Home rebuilds every second; the list only changes with [changes].
    if (_visibleAt == changes.value && _visible != null) return _visible!;
    final off = hidden();
    _visibleAt = changes.value;
    return _visible = [for (final d in all()) if (!off.contains(d.id)) d];
  }

  static List<Deed>? _visible;
  static int? _visibleAt;

  static Set<String> doneOn(DateTime day) => _strings(_dayKey(day)).toSet();

  static Future<void> toggle(DateTime day, String id) async {
    final done = doneOn(day);
    done.contains(id) ? done.remove(id) : done.add(id);
    await LocalStorageServices.setString(_dayKey(day), jsonEncode(done.toList()));
    await _record(day);
    changes.value++;
  }

  static Future<void> setShown(String id, bool shown, {DateTime? now}) async {
    final off = hidden();
    shown ? off.remove(id) : off.add(id);
    await LocalStorageServices.setString(_hiddenKey, jsonEncode(off.toList()));
    await _listChanged(now);
  }

  /// A new list only re-decides today; earlier days keep their outcome.
  static Future<void> _listChanged(DateTime? now) async {
    changes.value++;
    await _record(now ?? DateTime.now());
    changes.value++;
  }

  static Future<void> _record(DateTime day) =>
      LocalStorageServices.setBool(_fullKey(day), allDoneOn(day, visible()));

  static bool _wasFull(DateTime day) => LocalStorageServices.getBool(_fullKey(day)) ?? false;

  static Future<void> addCustom(String title, {DateTime? now}) async {
    final text = title.trim();
    if (text.isEmpty) return;
    final list = custom()..add(Deed('c${(now ?? DateTime.now()).microsecondsSinceEpoch}', title: text));
    await _saveCustom(list, now);
  }

  static Future<void> removeCustom(String id, {DateTime? now}) async {
    await _saveCustom(custom()..removeWhere((d) => d.id == id), now);
    // Nor kept in the hidden list, which would otherwise only grow.
    await setShown(id, true, now: now);
  }

  static Future<void> _saveCustom(List<Deed> list, DateTime? now) async {
    await LocalStorageServices.setString(
      _customKey,
      jsonEncode([for (final d in list) {'id': d.id, 'title': d.title}]),
    );
    await _listChanged(now);
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
    final key = (DateTime(today.year, today.month, today.day), changes.value);
    if (_streakFor == key && _streak != null) return _streak!;
    var day = key.$1;
    if (!_wasFull(day)) day = DateTime(day.year, day.month, day.day - 1);
    var n = 0;
    while (_wasFull(day) && n < 3650) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    _streakFor = key;
    return _streak = n;
  }

  static (DateTime, int)? _streakFor;
  static int? _streak;
}
