import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/constants/muezzins.dart';
import 'package:sakina/core/services/prayer_config.dart';
import 'package:sakina/core/services/prayer_notification_service.dart';
import 'package:sakina/core/services/prayer_times_service.dart';

void main() {
  final cairo = Coordinates(30.0444, 31.2357);
  const days = PrayerNotificationService.daysAhead;

  List<ScheduledAlert> planAt(
    DateTime now, {
    PrayerConfig config = const PrayerConfig(),
    Set<PrayerName>? prayers,
    int reminder = 0,
    bool kahf = false,
  }) => PrayerNotificationService.plan(
    coordinates: cairo,
    now: now,
    config: config,
    prayers: prayers ?? PrayerNotificationService.notifiedPrayers.toSet(),
    reminderMinutes: reminder,
    fridayKahf: kahf,
  );

  Iterable<ScheduledAlert> ofKind(List<ScheduledAlert> p, AlertKind k) =>
      p.where((a) => a.kind == k);

  // A Monday, so the 14-day window holds exactly two Fridays.
  final monday = DateTime(2026, 6, 15, 0, 1);

  test('schedules the five prayers a day and never sunrise', () {
    final plan = planAt(monday);
    expect(plan.length, 5 * days);
    expect(plan.any((a) => a.prayer == PrayerName.sunrise), isFalse);
  });

  test('never schedules anything in the past', () {
    // Android fires past-dated alarms immediately, which would be a burst of
    // stale notifications every time the app opens.
    final now = DateTime(2026, 6, 15, 15);
    for (final a in planAt(now, reminder: 30, kahf: true)) {
      expect(a.time.isAfter(now), isTrue, reason: '${a.kind} at ${a.time}');
    }
  });

  test('mid-afternoon drops the prayers already gone today', () {
    // Fajr and Dhuhr have passed; Asr, Maghrib and Isha remain today. The
    // moment is taken from the computed times so it holds in any timezone.
    final times = PrayerTimesService.computeFor(
      coordinates: cairo,
      date: DateTime(2026, 6, 15),
      config: const PrayerConfig(),
    );
    final dhuhr = times.entry(PrayerName.dhuhr).time;
    final asr = times.entry(PrayerName.asr).time;
    final between = dhuhr.add(asr.difference(dhuhr) ~/ 2);
    expect(planAt(between).length, 5 * days - 2);
  });

  test('everything is in chronological order', () {
    final plan = planAt(monday, reminder: 10, kahf: true);
    for (var i = 1; i < plan.length; i++) {
      expect(plan[i].time.isBefore(plan[i - 1].time), isFalse);
    }
  });

  test('ids are unique across every kind, so nothing overwrites anything', () {
    final ids = planAt(monday, reminder: 10, kahf: true).map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('a reminder comes the chosen minutes before its prayer', () {
    final plan = planAt(monday, reminder: 15);
    final prayers = ofKind(plan, AlertKind.prayer).toList();
    final reminders = ofKind(plan, AlertKind.reminder).toList();
    expect(reminders, hasLength(prayers.length));
    for (var i = 0; i < prayers.length; i++) {
      expect(prayers[i].time.difference(reminders[i].time), const Duration(minutes: 15));
      expect(reminders[i].prayer, prayers[i].prayer);
    }
  });

  test('no reminders when the setting is off', () {
    expect(ofKind(planAt(monday), AlertKind.reminder), isEmpty);
  });

  test('switched-off prayers are skipped', () {
    final plan = planAt(monday, prayers: {PrayerName.fajr, PrayerName.isha});
    expect(plan.map((a) => a.prayer).toSet(), {PrayerName.fajr, PrayerName.isha});
    expect(plan.length, 2 * days);
  });

  test('the Al-Kahf reminder falls on Friday mornings only', () {
    final kahf = ofKind(planAt(monday, kahf: true), AlertKind.kahf).toList();
    expect(kahf, hasLength(2));
    for (final a in kahf) {
      expect(a.time.weekday, DateTime.friday);
      expect(a.time.hour, 10);
    }
  });

  test('the calculation config reaches the schedule', () {
    final standard = ofKind(planAt(monday), AlertKind.prayer)
        .firstWhere((a) => a.prayer == PrayerName.asr);
    final hanafi = ofKind(planAt(monday, config: const PrayerConfig(madhab: 'hanafi')), AlertKind.prayer)
        .firstWhere((a) => a.prayer == PrayerName.asr);
    expect(hanafi.time.isAfter(standard.time), isTrue);
  });

  test('adhkar reminders come half an hour after Fajr and Asr, with unique ids', () {
    final plan = PrayerNotificationService.plan(
      coordinates: cairo,
      now: monday,
      reminderMinutes: 10,
      fridayKahf: true,
      adhkar: true,
    );
    final morning = ofKind(plan, AlertKind.morningAdhkar).toList();
    final evening = ofKind(plan, AlertKind.eveningAdhkar).toList();
    expect(morning, hasLength(days));
    expect(evening, hasLength(days));
    final fajr = ofKind(plan, AlertKind.prayer).firstWhere((a) => a.prayer == PrayerName.fajr);
    expect(morning.first.time.difference(fajr.time), PrayerNotificationService.adhkarAfterPrayer);
    final ids = plan.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('the khatma reminder comes daily, half an hour after Isha', () {
    final plan = PrayerNotificationService.plan(coordinates: cairo, now: monday, khatma: true, adhkar: true);
    final khatma = ofKind(plan, AlertKind.khatma).toList();
    expect(khatma, hasLength(days));
    final isha = ofKind(plan, AlertKind.prayer).firstWhere((a) => a.prayer == PrayerName.isha);
    expect(khatma.first.time.difference(isha.time), PrayerNotificationService.khatmaAfterIsha);
    final ids = plan.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ofKind(planAt(monday), AlertKind.khatma), isEmpty);
  });

  test('sunnah reminders: Duha mid-morning, Qiyam in the last third, Jumu\'ah on Fridays', () {
    final plan = PrayerNotificationService.plan(
      coordinates: cairo,
      now: monday,
      sunnah: SunnahAlert.values.toSet(),
      reminderMinutes: 10,
      adhkar: true,
      khatma: true,
      fridayKahf: true,
    );
    final day0 = PrayerTimesService.computeFor(coordinates: cairo, date: DateTime(2026, 6, 15), config: const PrayerConfig());
    final day1 = PrayerTimesService.computeFor(coordinates: cairo, date: DateTime(2026, 6, 16), config: const PrayerConfig());

    final duha = ofKind(plan, AlertKind.duha).first.time;
    expect(duha.isAfter(day0.entry(PrayerName.sunrise).time), isTrue);
    expect(duha.isBefore(day0.entry(PrayerName.dhuhr).time), isTrue);

    // The night runs Maghrib to the next Fajr; its last third starts two
    // thirds of the way through.
    final maghrib = day0.entry(PrayerName.maghrib).time;
    final nextFajr = day1.entry(PrayerName.fajr).time;
    final qiyam = ofKind(plan, AlertKind.qiyam).firstWhere((a) => a.time.isAfter(maghrib)).time;
    final expected = nextFajr.subtract(nextFajr.difference(maghrib) ~/ 3);
    expect(qiyam.difference(expected).inSeconds.abs(), lessThan(60));
    expect(qiyam.difference(maghrib).inMinutes, closeTo(nextFajr.difference(maghrib).inMinutes * 2 / 3, 1));

    final jumuah = ofKind(plan, AlertKind.jumuah).toList();
    expect(jumuah, hasLength(2), reason: 'two Fridays in two weeks');
    for (final a in jumuah) {
      expect(a.time.weekday, DateTime.friday);
    }

    expect(ofKind(plan, AlertKind.duha), hasLength(days));
    final ids = plan.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ofKind(planAt(monday), AlertKind.qiyam), isEmpty);
  });

  test("a schedule rebuilt during the night keeps that night's Qiyam", () {
    // Rebuilt a minute before the last third begins: after midnight that is
    // the night of yesterday's Maghrib, which day 0 alone would miss.
    final maghrib = PrayerTimesService.computeFor(coordinates: cairo, date: DateTime(2026, 6, 15), config: const PrayerConfig())
        .entry(PrayerName.maghrib)
        .time;
    final lastThird = PrayerNotificationService.lastThirdOfNight(maghrib, cairo, const PrayerConfig());
    final now = lastThird.subtract(const Duration(minutes: 1));
    final plan = PrayerNotificationService.plan(coordinates: cairo, now: now, sunnah: {SunnahAlert.qiyam});
    expect(ofKind(plan, AlertKind.qiyam).where((a) => a.time.difference(lastThird).inSeconds.abs() < 60), hasLength(1));
    final ids = plan.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every calendar day is planned once, across a clock change', () {
    // Egypt and Europe put their clocks back in late October; run this file
    // with TZ=Africa/Cairo or TZ=Europe/Berlin to exercise it.
    final plan = PrayerNotificationService.plan(
      coordinates: cairo,
      now: DateTime(2026, 10, 20),
      sunnah: SunnahAlert.values.toSet(),
    );
    final fajrDays = [
      for (final a in ofKind(plan, AlertKind.prayer).where((a) => a.prayer == PrayerName.fajr))
        DateTime(a.time.year, a.time.month, a.time.day),
    ];
    expect(fajrDays.toSet().length, days);

    DateTime maghribOn(DateTime d) =>
        PrayerTimesService.computeFor(coordinates: cairo, date: d, config: const PrayerConfig())
            .entry(PrayerName.maghrib)
            .time;
    for (final q in ofKind(plan, AlertKind.qiyam)) {
      // Each falls within the night after some Maghrib, never mid-morning.
      final day = DateTime(q.time.year, q.time.month, q.time.day);
      final inNight = [maghribOn(day), maghribOn(DateTime(day.year, day.month, day.day - 1))]
          .any((m) => q.time.isAfter(m) && q.time.difference(m) < const Duration(hours: 14));
      expect(inNight, isTrue, reason: '${q.time}');
    }
  });

  test('no adhkar reminders unless asked for', () {
    final plan = planAt(monday);
    expect(ofKind(plan, AlertKind.morningAdhkar), isEmpty);
    expect(ofKind(plan, AlertKind.eveningAdhkar), isEmpty);
  });

  group('channelFor', () {
    String channel(AlertKind kind, PrayerName? prayer, PrayerSound sound) =>
        PrayerNotificationService.channelFor(kind, prayer, sound);

    test('Fajr gets its own adhan, the other four share one', () {
      expect(
        channel(AlertKind.prayer, PrayerName.fajr, PrayerSound.adhan),
        PrayerNotificationService.fajrAdhanChannel,
      );
      for (final p in [PrayerName.dhuhr, PrayerName.asr, PrayerName.maghrib, PrayerName.isha]) {
        expect(channel(AlertKind.prayer, p, PrayerSound.adhan), PrayerNotificationService.adhanChannel);
      }
    });

    test('the other sounds apply to every prayer, Fajr included', () {
      for (final p in PrayerNotificationService.notifiedPrayers) {
        expect(channel(AlertKind.prayer, p, PrayerSound.standard), PrayerNotificationService.standardChannel);
        expect(channel(AlertKind.prayer, p, PrayerSound.silent), PrayerNotificationService.silentChannel);
      }
    });

    test('a muezzin falls back to their own adhan, then the default, then the plain sound', () {
      final makkah = Muezzins.unbundled.firstWhere((m) => m.id == 'makkah');
      expect(PrayerNotificationService.channelsFor(AlertKind.prayer, PrayerName.fajr, PrayerSound.adhan, makkah), [
        'prayer_adhan_makkah_fajr',
        'prayer_adhan_makkah',
        PrayerNotificationService.fajrAdhanChannel,
        PrayerNotificationService.adhanChannel,
        PrayerNotificationService.standardChannel,
      ]);
      expect(PrayerNotificationService.channelsFor(AlertKind.prayer, PrayerName.isha, PrayerSound.adhan, makkah), [
        'prayer_adhan_makkah',
        PrayerNotificationService.adhanChannel,
        PrayerNotificationService.standardChannel,
      ]);
    });

    test('every muezzin Settings offers has its recording bundled', () {
      // A choice with no file would quietly play the default adhan.
      for (final m in Muezzins.all) {
        final bundled = ['ogg', 'mp3'].any((ext) => File('android/app/src/main/res/raw/${m.sound}.$ext').existsSync());
        expect(bundled, isTrue, reason: m.sound);
        expect(File('android/app/src/main/res/raw/keep.xml').readAsStringSync(), contains('@raw/${m.sound},'));
      }
    });

    test('the default muezzin keeps the channels existing installs already have', () {
      expect(PrayerNotificationService.adhanChannel, 'prayer_adhan');
      expect(PrayerNotificationService.fajrAdhanChannel, 'prayer_adhan_fajr');
      expect(
        PrayerNotificationService.channelsFor(AlertKind.prayer, PrayerName.fajr, PrayerSound.adhan),
        ['prayer_adhan_fajr', 'prayer_adhan', PrayerNotificationService.standardChannel],
      );
      expect(Muezzins.byId('nobody'), Muezzins.standard);
      // Saved by an earlier version that listed it before its file shipped.
      expect(Muezzins.byId('makkah'), Muezzins.standard);
    });

    test('reminders and other alerts never play the adhan', () {
      // A reminder ten minutes early that sounds like the adhan would be
      // mistaken for the prayer itself.
      for (final kind in AlertKind.values.where((k) => k != AlertKind.prayer)) {
        for (final sound in PrayerSound.values) {
          expect(channel(kind, PrayerName.fajr, sound), PrayerNotificationService.standardChannel);
        }
      }
    });
  });
}
