import 'dart:async';
import 'dart:math';

import '../constants/prefs_keys.dart';
import 'prayer_times_service.dart';
import 'review_prompt.dart';
import 'shared_prefs_helper.dart';

/// Which of the five prayers were logged on each day, one bitmask per day.
abstract final class PrayerTracker {
  static const List<PrayerName> prayers = [
    PrayerName.fajr,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  ];

  static const int _all = 0x1F;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static int maskFor(DateTime day) =>
      LocalStorageServices.getInt(PrefsKeys.prayerLog(_day(day))) ?? 0;

  static bool isDone(DateTime day, PrayerName prayer) {
    final bit = prayers.indexOf(prayer);
    return bit >= 0 && maskFor(day) & (1 << bit) != 0;
  }

  static int countFor(DateTime day) {
    final mask = maskFor(day);
    var n = 0;
    for (var i = 0; i < prayers.length; i++) {
      if (mask & (1 << i) != 0) n++;
    }
    return n;
  }

  static Future<void> toggle(DateTime day, PrayerName prayer) async {
    final bit = prayers.indexOf(prayer);
    if (bit < 0) return; // Sunrise is not a prayer to log.
    final mask = maskFor(day) ^ (1 << bit);
    await LocalStorageServices.setInt(PrefsKeys.prayerLog(_day(day)), mask);
    // Completing today is a good moment to ask for a rating, counted once a
    // day however often a prayer is unticked and ticked again.
    final key = PrefsKeys.prayerLog(_day(day));
    if (mask == _all &&
        _day(day) == _day(DateTime.now()) &&
        LocalStorageServices.getString(PrefsKeys.reviewTrackerDay) != key) {
      await LocalStorageServices.setString(PrefsKeys.reviewTrackerDay, key);
      unawaited(ReviewPrompt.noteGoodMoment());
    }
  }

  /// Consecutive days with all five prayers, counting back from [today].
  /// Today counts only once complete, so an unfinished today does not break
  /// a streak that ran up to yesterday.
  static int streak(DateTime today) {
    var day = _day(today);
    // Calendar days back, not 24-hour steps, which skip a date at a clock change.
    if (maskFor(day) != _all) day = DateTime(day.year, day.month, day.day - 1);
    var n = 0;
    while (maskFor(day) == _all) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }

  /// The [days] calendar days ending with [today], oldest first.
  static List<DateTime> lastDays(DateTime today, int days) => [
    for (var i = days - 1; i >= 0; i--) DateTime(today.year, today.month, today.day - i),
  ];

  /// On how many of the [days] days ending with [today] [prayer] was logged.
  static int daysDone(PrayerName prayer, DateTime today, int days) =>
      lastDays(today, days).where((d) => isDone(d, prayer)).length;

  /// The longest run of days with all five prayers in the [lookback] days
  /// ending with [today].
  static int bestStreak(DateTime today, {int lookback = 365}) {
    var best = 0;
    var run = 0;
    for (final day in lastDays(today, lookback)) {
      run = maskFor(day) == _all ? run + 1 : 0;
      if (run > best) best = run;
    }
    // A run longer than the lookback is still the best, and still going.
    return max(best, streak(today));
  }

  /// Share of prayers logged this month up to and including [today], 0..100.
  static int monthPercent(DateTime today) {
    var logged = 0;
    for (var d = 1; d <= today.day; d++) {
      logged += countFor(DateTime(today.year, today.month, d));
    }
    return (logged * 100 / (today.day * prayers.length)).round();
  }
}
