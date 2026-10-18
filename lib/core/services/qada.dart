import '../constants/prefs_keys.dart';
import 'prayer_times_service.dart';
import 'prayer_tracker.dart';
import 'shared_prefs_helper.dart';

/// Missed prayers still to be made up (qada), counted per prayer.
abstract final class Qada {
  static int count(PrayerName prayer) => LocalStorageServices.getInt(PrefsKeys.qada(prayer.name)) ?? 0;

  static int get total => PrayerTracker.prayers.fold(0, (sum, p) => sum + count(p));

  /// Adds [n] to [prayer], or takes away for a negative [n]; never below 0.
  static Future<void> add(PrayerName prayer, int n) =>
      LocalStorageServices.setInt(PrefsKeys.qada(prayer.name), (count(prayer) + n).clamp(0, 1 << 30));

  /// Adds [days] of all five prayers, for someone estimating what they missed.
  static Future<void> addDays(int days) async {
    for (final p in PrayerTracker.prayers) {
      await add(p, days);
    }
  }
}
