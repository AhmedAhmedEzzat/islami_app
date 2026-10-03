import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/prayer_times_service.dart';

void main() {
  final cairo = Coordinates(30.0444, 31.2357);

  group('PrayerTimesService.computeFor', () {
    test('returns the six daily prayers in chronological order', () {
      final result = PrayerTimesService.computeFor(
        coordinates: cairo,
        date: DateTime(2026, 6, 15, 9),
      );

      expect(result.prayers, hasLength(6));
      expect(
        result.prayers.map((p) => p.prayer),
        [
          PrayerName.fajr,
          PrayerName.sunrise,
          PrayerName.dhuhr,
          PrayerName.asr,
          PrayerName.maghrib,
          PrayerName.isha,
        ],
      );

      for (var i = 1; i < result.prayers.length; i++) {
        expect(
          result.prayers[i].time.isAfter(result.prayers[i - 1].time),
          isTrue,
          reason: '${result.prayers[i].prayer.name} should follow '
              '${result.prayers[i - 1].prayer.name}',
        );
      }
    });

    test('picks the next upcoming prayer for a mid-morning time', () {
      final result = PrayerTimesService.computeFor(
        coordinates: cairo,
        date: DateTime(2026, 6, 15, 9),
      );
      // 09:00 is after sunrise and before Duhr.
      expect(result.next!.prayer, PrayerName.dhuhr);
      expect(result.untilNext!.isNegative, isFalse);
    });

    test('rolls over to tomorrow\'s Fajr late at night', () {
      final result = PrayerTimesService.computeFor(
        coordinates: cairo,
        date: DateTime(2026, 6, 15, 23, 59),
      );
      expect(result.next!.prayer, PrayerName.fajr);
      expect(result.next!.time.isAfter(DateTime(2026, 6, 15, 23, 59)), isTrue);
      expect(result.untilNext!.isNegative, isFalse);
    });

    test('produces different times for different latitudes', () {
      final oslo = PrayerTimesService.computeFor(
        coordinates: Coordinates(59.9139, 10.7522),
        date: DateTime(2026, 6, 15, 9),
      );
      final egypt = PrayerTimesService.computeFor(
        coordinates: cairo,
        date: DateTime(2026, 6, 15, 9),
      );
      expect(oslo.prayers.first.time, isNot(egypt.prayers.first.time));
    });

    test('flags when the fallback location was used', () {
      final result = PrayerTimesService.computeFor(
        coordinates: PrayerTimesService.fallbackCoordinates,
        date: DateTime(2026, 6, 15, 9),
        usedFallbackLocation: true,
      );
      expect(result.usedFallbackLocation, isTrue);
    });
  });
}
