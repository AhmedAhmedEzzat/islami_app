import 'package:flutter/foundation.dart';

import '../constants/prefs_keys.dart';
import 'shared_prefs_helper.dart';

/// Mushaf pages read each day: today's count, the week's, and the streak of
/// days with some reading. A page counts once a day however often it is
/// turned back to.
abstract final class ReadingStats {
  /// Days kept; older ones are dropped as new ones are written.
  static const int keepDays = 120;

  /// Bumped when today's reading changes, for widgets to rebuild on.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Set<int> _pages(DateTime day) => {
    for (final p in LocalStorageServices.getStringList(PrefsKeys.readingDay(_key(day))) ?? const <String>[])
      ?int.tryParse(p),
  };

  static int pagesOn(DateTime day) => _pages(_day(day)).length;

  /// Pages read in the seven days ending [today].
  static int pagesThisWeek(DateTime today) {
    var n = 0;
    for (var i = 0; i < 7; i++) {
      n += pagesOn(today.subtract(Duration(days: i)));
    }
    return n;
  }

  /// Consecutive days with some reading, counting back from [today]. Today
  /// counts once read in, so an unread today does not break yesterday's run.
  static int streak(DateTime today) {
    var day = _day(today);
    if (pagesOn(day) == 0) day = day.subtract(const Duration(days: 1));
    var n = 0;
    while (n < keepDays && pagesOn(day) > 0) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Records that [page] was read [at] (now by default).
  static Future<void> notePage(int page, {DateTime? at}) async {
    final day = _day(at ?? DateTime.now());
    final pages = _pages(day);
    if (!pages.add(page)) return;
    await LocalStorageServices.setStringList(PrefsKeys.readingDay(_key(day)), [for (final p in pages) '$p']);

    // Remember which days have entries, and drop the ones past keepDays.
    final days = {...?LocalStorageServices.getStringList(PrefsKeys.readingDays), _key(day)};
    final cutoff = _key(day.subtract(const Duration(days: keepDays)));
    final old = days.where((k) => k.compareTo(cutoff) < 0).toList();
    if (old.isNotEmpty) {
      await LocalStorageServices.remove([for (final k in old) PrefsKeys.readingDay(k)]);
      days.removeAll(old);
    }
    await LocalStorageServices.setStringList(PrefsKeys.readingDays, days.toList()..sort());
    changes.value++;
  }
}
