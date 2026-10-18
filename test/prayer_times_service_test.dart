import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/prayer_times_service.dart';

void main() {
  final cairo = Coordinates(30.0444, 31.2357);
  // Cairo's latitude, at the longitude whose sun matches the test machine's
  // clock, for tests about the time of day in any timezone.
  final local = Coordinates(30.0444, _localLongitude());

  test('no day is skipped or repeated, even by the 180th meridian', () {
    // The adhan library put Fiji's times a day late whenever solar noon
    // slipped just before midnight UTC, which skipped a date, and gave
    // Samoa and Tonga the next day's times.
    final places = {
      'Suva': Coordinates(-18.14, 178.44),
      'Labasa': Coordinates(-16.43, 179.38),
      'Nukualofa': Coordinates(-21.14, -175.2),
      'Apia': Coordinates(-13.83, -171.76),
      'Auckland': Coordinates(-36.85, 174.76),
      'Cairo': cairo,
      'Honolulu': Coordinates(21.3, -157.8),
    };
    for (final MapEntry(key: name, value: place) in places.entries) {
      List<PrayerEntry>? last;
      for (var d = 0; d <= 366; d++) {
        final day = DateTime(2026, 1, 1 + d);
        final prayers = PrayerTimesService.computeFor(coordinates: place, date: day).prayers;
        if (last != null) {
          for (var p = 0; p < prayers.length; p++) {
            // Instants, so a clock change does not count. The library does
            // shift an hour on the day the test machine's own clock changes,
            // when a place this far away has a prayer in that repeated hour.
            final step = prayers[p].time.difference(last[p].time).inMinutes;
            final offsets = {for (var k = -1; k <= 2; k++) DateTime(day.year, day.month, day.day + k).timeZoneOffset};
            final slack = offsets.length == 1 ? 5 : 65;
            expect(step, inInclusiveRange(24 * 60 - slack, 24 * 60 + slack), reason: '$name ${prayers[p].prayer.name} $day');
          }
        }
        last = prayers;
      }
    }
  });

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
        coordinates: local,
        date: DateTime(2026, 6, 15, 9),
      );
      // 09:00 is after sunrise and before Duhr.
      expect(result.next!.prayer, PrayerName.dhuhr);
      expect(result.untilNext!.isNegative, isFalse);
    });

    test('rolls over to tomorrow\'s Fajr late at night', () {
      final result = PrayerTimesService.computeFor(
        coordinates: local,
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

/// The longitude where local clock time is roughly solar time.
double _localLongitude() {
  final longitude = DateTime(2026, 6, 15).timeZoneOffset.inMinutes / 4;
  return longitude > 180 ? longitude - 360 : longitude;
}
