import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';

import 'prayer_times_service.dart';

/// Every setting that changes when a prayer falls.
///
/// One value object, so the Time tab, the notification schedule and the
/// monthly timetable can never compute times with different settings.
@immutable
class PrayerConfig {
  const PrayerConfig({
    this.method = 'egyptian',
    this.madhab = 'shafi',
    this.highLatitude = 'middle',
    this.adjustments = const {},
  });

  /// See [PrayerConfig.methods].
  final String method;

  /// 'shafi' (Asr at shadow = 1x) or 'hanafi' (2x).
  final String madhab;

  /// How Fajr and Isha are found where twilight never fully ends:
  /// 'middle' of the night, 'seventh' of the night, or 'twilight' angle.
  final String highLatitude;

  /// Minutes added to each prayer, for matching a local mosque.
  final Map<PrayerName, int> adjustments;

  static const List<String> methods = [
    'egyptian',
    'muslimWorldLeague',
    'ummAlQura',
    'karachi',
    'northAmerica',
    'dubai',
    'kuwait',
    'qatar',
    'singapore',
    'turkey',
    'tehran',
    'moonsightingCommittee',
  ];

  int adjustmentFor(PrayerName p) => adjustments[p] ?? 0;

  CalculationParameters toParameters() {
    final params = switch (method) {
      'muslimWorldLeague' => CalculationMethod.muslim_world_league,
      'ummAlQura' => CalculationMethod.umm_al_qura,
      'karachi' => CalculationMethod.karachi,
      'northAmerica' => CalculationMethod.north_america,
      'dubai' => CalculationMethod.dubai,
      'kuwait' => CalculationMethod.kuwait,
      'qatar' => CalculationMethod.qatar,
      'singapore' => CalculationMethod.singapore,
      'turkey' => CalculationMethod.turkey,
      'tehran' => CalculationMethod.tehran,
      'moonsightingCommittee' => CalculationMethod.moon_sighting_committee,
      _ => CalculationMethod.egyptian,
    }.getParameters();

    params.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    params.highLatitudeRule = switch (highLatitude) {
      'seventh' => HighLatitudeRule.seventh_of_the_night,
      'twilight' => HighLatitudeRule.twilight_angle,
      _ => HighLatitudeRule.middle_of_the_night,
    };
    // Added to whatever the method itself already adjusts.
    params.adjustments.fajr += adjustmentFor(PrayerName.fajr);
    params.adjustments.sunrise += adjustmentFor(PrayerName.sunrise);
    params.adjustments.dhuhr += adjustmentFor(PrayerName.dhuhr);
    params.adjustments.asr += adjustmentFor(PrayerName.asr);
    params.adjustments.maghrib += adjustmentFor(PrayerName.maghrib);
    params.adjustments.isha += adjustmentFor(PrayerName.isha);
    return params;
  }

  /// "fajr:2,isha:-3" — only non-zero entries.
  static String encodeAdjustments(Map<PrayerName, int> a) => a.entries
      .where((e) => e.value != 0)
      .map((e) => '${e.key.name}:${e.value}')
      .join(',');

  static Map<PrayerName, int> decodeAdjustments(String? raw) {
    final result = <PrayerName, int>{};
    if (raw == null || raw.isEmpty) return result;
    for (final part in raw.split(',')) {
      final kv = part.split(':');
      if (kv.length != 2) continue;
      final prayer = PrayerName.values.where((p) => p.name == kv[0]).firstOrNull;
      final minutes = int.tryParse(kv[1]);
      if (prayer != null && minutes != null) result[prayer] = minutes;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is PrayerConfig &&
      other.method == method &&
      other.madhab == madhab &&
      other.highLatitude == highLatitude &&
      mapEquals(other.adjustments, adjustments);

  @override
  int get hashCode => Object.hash(
    method,
    madhab,
    highLatitude,
    encodeAdjustments(adjustments),
  );
}
