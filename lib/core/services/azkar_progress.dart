import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/zikr_model.dart';
import '../constants/prefs_keys.dart';
import 'shared_prefs_helper.dart';

/// How far through each chapter's counts the reader has got, kept so a
/// chapter left half-way (a phone call, another screen) is picked up where it
/// was instead of starting again from the top.
///
/// Progress belongs to a sitting. For most chapters that is the day; the
/// morning and evening adhkar are one chapter read twice a day, so theirs is
/// the half of the day, and the evening starts fresh after the morning.
abstract final class AzkarProgress {
  /// Bumped on every change, for the index to redraw its ticks.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  /// The sitting [chapterId] belongs to at [now].
  @visibleForTesting
  static String sitting(int chapterId, DateTime now) {
    final day =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (chapterId != FeaturedAzkar.morningEvening) return day;
    return now.hour < 12 ? '$day-am' : '$day-pm';
  }

  /// Everything saved: chapter id to its sitting ("s") and counts left ("r").
  static Map<String, dynamic> _all() {
    final raw = LocalStorageServices.getString(PrefsKeys.azkarProgress);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? json : {};
    } catch (_) {
      return {};
    }
  }

  /// The counts left for each dhikr of [chapter], in order, or null when
  /// nothing is saved for this sitting or what is saved does not fit the
  /// chapter (favourites added or removed since).
  static List<int>? remaining(AzkarChapter chapter, {DateTime? now}) {
    final entry = _all()['${chapter.id}'];
    if (entry is! Map ||
        entry['s'] != sitting(chapter.id, now ?? DateTime.now())) {
      return null;
    }
    final left = entry['r'];
    if (left is! List || left.length != chapter.items.length) return null;
    final result = <int>[];
    for (var i = 0; i < left.length; i++) {
      final v = left[i];
      if (v is! int) return null;
      result.add(v.clamp(0, chapter.items[i].count));
    }
    return result;
  }

  /// Saves [left], the counts left for each dhikr of [chapter] in order.
  static Future<void> save(
    AzkarChapter chapter,
    List<int> left, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final all = _all()
      // Other chapters' sittings that have ended are dropped as we go.
      ..removeWhere((id, e) {
        final chapterId = int.tryParse(id);
        return chapterId == null ||
            e is! Map ||
            e['s'] != sitting(chapterId, at);
      });
    all['${chapter.id}'] = {'s': sitting(chapter.id, at), 'r': left};
    await LocalStorageServices.setString(
      PrefsKeys.azkarProgress,
      jsonEncode(all),
    );
    changes.value++;
  }

  /// Forgets [chapter]'s progress.
  static Future<void> clear(AzkarChapter chapter) async {
    final all = _all();
    if (all.remove('${chapter.id}') == null) return;
    await LocalStorageServices.setString(
      PrefsKeys.azkarProgress,
      jsonEncode(all),
    );
    changes.value++;
  }

  /// The share of [chapter]'s adhkar finished in this sitting, 0 to 1.
  static double fraction(AzkarChapter chapter, {DateTime? now}) {
    final left = remaining(chapter, now: now);
    if (left == null || left.isEmpty) return 0;
    return left.where((r) => r == 0).length / left.length;
  }
}
