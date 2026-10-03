import '../constants/prefs_keys.dart';
import 'prayer_times_service.dart';
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
    await LocalStorageServices.setInt(
      PrefsKeys.prayerLog(_day(day)),
      maskFor(day) ^ (1 << bit),
    );
  }

  /// Consecutive days with all five prayers, counting back from [today].
  /// Today counts only once complete, so an unfinished today does not break
  /// a streak that ran up to yesterday.
  static int streak(DateTime today) {
    var day = _day(today);
    if (maskFor(day) != _all) day = day.subtract(const Duration(days: 1));
    var n = 0;
    while (maskFor(day) == _all) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
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
