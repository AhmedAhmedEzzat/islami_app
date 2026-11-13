import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/zikr_model.dart';
import 'daily_deeds.dart';
import 'shared_prefs_helper.dart';

/// Where the reader got to in each Hisn al-Muslim chapter, kept until the
/// chapter is due again.
///
/// Without this, leaving the morning adhkar to answer a call threw away every
/// count. A chapter is due again the next day; the morning and evening
/// adhkar, read twice a day, are due again at noon and at midnight.
abstract final class AzkarProgress {
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static String _key(int chapterId) => 'azkar.progress.$chapterId';
  static const String fontScaleKey = 'azkar.fontScale';

  static const double minFontScale = 0.8;
  static const double maxFontScale = 1.8;

  /// The reading the counts belong to: a day, or half a day for the morning
  /// and evening adhkar.
  static String session(int chapterId, DateTime now) {
    final day = '${now.year}-${now.month}-${now.day}';
    if (chapterId != FeaturedAzkar.morningEvening) return day;
    return '$day-${isMorning(now) ? 'am' : 'pm'}';
  }

  /// Morning adhkar before noon, evening adhkar from noon on.
  static bool isMorning(DateTime now) => now.hour < 12;

  /// The counts left, by dhikr id, if this chapter was started in the
  /// current session; null if it is due afresh.
  static Map<int, int>? load(int chapterId, DateTime now) {
    final raw = LocalStorageServices.getString(_key(chapterId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['session'] != session(chapterId, now)) return null;
      final left = json['left'];
      if (left is! Map) return null;
      return {
        for (final e in left.entries)
          if (int.tryParse('${e.key}') != null && e.value is int) int.parse('${e.key}'): e.value as int,
      };
    } catch (_) {
      return null;
    }
  }

  /// The chapter's counts as they stand, with stored progress applied to the
  /// adhkar it still names. A dhikr missing from storage starts in full.
  static Map<int, int> remaining(AzkarChapter chapter, DateTime now) {
    final stored = load(chapter.id, now) ?? const {};
    return {for (final z in chapter.items) z.id: (stored[z.id] ?? z.count).clamp(0, z.count)};
  }

  static Future<void> save(int chapterId, DateTime now, Map<int, int> left) async {
    await LocalStorageServices.setString(
      _key(chapterId),
      jsonEncode({
        'session': session(chapterId, now),
        // [left] holds every dhikr of the chapter, so this is the whole of it.
        'finished': left.isNotEmpty && left.values.every((v) => v == 0),
        'left': {for (final e in left.entries) '${e.key}': e.value},
      }),
    );
    changes.value++;
  }

  static Future<void> clear(int chapterId) async {
    await LocalStorageServices.remove([_key(chapterId)]);
    changes.value++;
  }

  /// Whether the whole chapter was read in the current session, for
  /// shortcuts that do not load the chapter itself.
  static bool isFinished(int chapterId, DateTime now) {
    final raw = LocalStorageServices.getString(_key(chapterId));
    if (raw == null || raw.isEmpty) return false;
    try {
      final json = jsonDecode(raw);
      return json is Map && json['session'] == session(chapterId, now) && json['finished'] == true;
    } catch (_) {
      return false;
    }
  }

  /// How many of the chapter's adhkar are finished in the current session.
  static int doneCount(AzkarChapter chapter, DateTime now) {
    final stored = load(chapter.id, now);
    if (stored == null) return 0;
    return chapter.items.where((z) => stored[z.id] == 0).length;
  }

  /// The daily deed that finishing [chapterId] now completes, if any.
  static String? deedFor(int chapterId, DateTime now) {
    if (chapterId != FeaturedAzkar.morningEvening) return null;
    return isMorning(now) ? 'morningAdhkar' : 'eveningAdhkar';
  }

  /// Ticks the matching deed on the daily checklist, never unticks it.
  static Future<void> recordFinished(int chapterId, DateTime now) async {
    final deed = deedFor(chapterId, now);
    if (deed == null) return;
    if (DailyDeeds.doneOn(now).contains(deed)) return;
    await DailyDeeds.toggle(now, deed);
  }

  static double fontScale() =>
      (LocalStorageServices.getDouble(fontScaleKey) ?? 1).clamp(minFontScale, maxFontScale);

  static Future<void> setFontScale(double value) async {
    await LocalStorageServices.setDouble(fontScaleKey, value.clamp(minFontScale, maxFontScale));
    changes.value++;
  }
}
