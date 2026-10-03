import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/prayer_config.dart';
import 'package:sakina/core/services/prayer_times_service.dart';
import 'package:sakina/core/services/prayer_tracker.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> logAll(DateTime day) async {
  for (final p in PrayerTracker.prayers) {
    await PrayerTracker.toggle(day, p);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrayerTracker', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageServices.init();
    });

    final today = DateTime(2026, 10, 15, 14, 30);

    test('toggle marks and unmarks a prayer', () async {
      await PrayerTracker.toggle(today, PrayerName.asr);
      expect(PrayerTracker.isDone(today, PrayerName.asr), isTrue);
      expect(PrayerTracker.countFor(today), 1);
      await PrayerTracker.toggle(today, PrayerName.asr);
      expect(PrayerTracker.isDone(today, PrayerName.asr), isFalse);
    });

    test('sunrise cannot be logged', () async {
      await PrayerTracker.toggle(today, PrayerName.sunrise);
      expect(PrayerTracker.countFor(today), 0);
    });

    test('the time of day does not matter, only the date', () async {
      await PrayerTracker.toggle(DateTime(2026, 10, 15, 5), PrayerName.fajr);
      expect(PrayerTracker.isDone(DateTime(2026, 10, 15, 23), PrayerName.fajr), isTrue);
    });

    test('streak counts complete days back from yesterday', () async {
      for (var i = 1; i <= 3; i++) {
        await logAll(today.subtract(Duration(days: i)));
      }
      // Today is unfinished: it must not break the streak.
      await PrayerTracker.toggle(today, PrayerName.fajr);
      expect(PrayerTracker.streak(today), 3);
    });

    test('a complete today extends the streak', () async {
      await logAll(today.subtract(const Duration(days: 1)));
      await logAll(today);
      expect(PrayerTracker.streak(today), 2);
    });

    test('a gap ends the streak', () async {
      await logAll(today.subtract(const Duration(days: 1)));
      await logAll(today.subtract(const Duration(days: 3)));
      expect(PrayerTracker.streak(today), 1);
    });

    test('month percentage covers only days so far', () async {
      final early = DateTime(2026, 10, 2);
      await logAll(DateTime(2026, 10, 1));
      expect(PrayerTracker.monthPercent(early), 50);
    });
  });

  group('PrayerConfig', () {
    final cairo = Coordinates(30.0444, 31.2357);
    final date = DateTime(2026, 6, 15, 9);

    DateTime asrWith(PrayerConfig c) => PrayerTimesService.computeFor(
      coordinates: cairo,
      date: date,
      config: c,
    ).entry(PrayerName.asr).time;

    test('Hanafi Asr is later than the standard Asr', () {
      expect(
        asrWith(const PrayerConfig(madhab: 'hanafi')).isAfter(asrWith(const PrayerConfig())),
        isTrue,
      );
    });

    test('a minute adjustment shifts only that prayer', () {
      final base = PrayerTimesService.computeFor(coordinates: cairo, date: date);
      final moved = PrayerTimesService.computeFor(
        coordinates: cairo,
        date: date,
        config: const PrayerConfig(adjustments: {PrayerName.isha: 5}),
      );
      expect(
        moved.entry(PrayerName.isha).time.difference(base.entry(PrayerName.isha).time),
        const Duration(minutes: 5),
      );
      expect(moved.entry(PrayerName.fajr).time, base.entry(PrayerName.fajr).time);
    });

    test('adjustments round-trip through storage, dropping zeros', () {
      const map = {PrayerName.fajr: 2, PrayerName.isha: -3, PrayerName.asr: 0};
      final encoded = PrayerConfig.encodeAdjustments(map);
      expect(encoded, isNot(contains('asr')));
      expect(PrayerConfig.decodeAdjustments(encoded), {PrayerName.fajr: 2, PrayerName.isha: -3});
    });

    test('garbage in storage decodes to nothing rather than throwing', () {
      expect(PrayerConfig.decodeAdjustments('nonsense,fajr:x,:3'), isEmpty);
    });

    test('every listed method computes times', () {
      for (final m in PrayerConfig.methods) {
        final r = PrayerTimesService.computeFor(
          coordinates: cairo,
          date: date,
          config: PrayerConfig(method: m),
        );
        expect(r.prayers, hasLength(6), reason: m);
      }
    });

    test('a month has one row per day', () {
      final month = PrayerTimesService.computeMonth(coordinates: cairo, month: DateTime(2026, 2, 10));
      expect(month, hasLength(28));
      expect(month.first.$1, DateTime(2026, 2, 1));
    });

    test('the Qibla from Cairo points south-east', () {
      final bearing = PrayerTimesService.qiblaBearing(cairo);
      expect(bearing, inInclusiveRange(130, 140));
    });
  });
}
