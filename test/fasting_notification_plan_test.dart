import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/islamic_calendar.dart';
import 'package:sakina/core/services/prayer_notification_service.dart';
import 'package:sakina/core/services/prayer_times_service.dart';

void main() {
  // Cairo's latitude, at the longitude whose sun matches the test machine's
  // clock, so each day's prayers fall on that local calendar day in any
  // timezone, as they do on a phone set to where its owner is.
  final place = Coordinates(30.0444, _localLongitude());
  const eveKinds = {AlertKind.mondayThursday, AlertKind.whiteDays, AlertKind.arafah, AlertKind.ashura};

  /// Only the fasting alerts, from just after midnight of Hijri [year]/[month]/[day].
  List<ScheduledAlert> fastingFrom(int year, int month, int day, Set<FastingAlert> fasting) {
    final start = IslamicCalendar.toGregorian(year, month, day).add(const Duration(minutes: 1));
    return PrayerNotificationService.plan(coordinates: place, now: start, prayers: const {}, fasting: fasting)
        .where((a) => eveKinds.contains(a.kind) || a.kind == AlertKind.suhoor || a.kind == AlertKind.iftar)
        .toList();
  }

  /// The Hijri date of the day the evening reminder is for.
  ({int month, int day}) fastDay(ScheduledAlert a) {
    final h = IslamicCalendar.of(a.time.add(const Duration(days: 1)));
    return (month: h.hMonth, day: h.hDay);
  }

  test('nothing about fasting when every fasting switch is off', () {
    expect(fastingFrom(1448, 9, 1, const {}), isEmpty);
  });

  test('Monday and Thursday: the evening before each, at nine', () {
    final plan = fastingFrom(1448, 4, 1, {FastingAlert.mondayThursday});
    expect(plan.length, 4); // two weeks, two fasts a week
    for (final a in plan) {
      expect(a.kind, AlertKind.mondayThursday);
      expect(a.time.weekday, anyOf(DateTime.sunday, DateTime.wednesday));
      expect(a.time.hour, PrayerNotificationService.eveningHour);
    }
  });

  test('White Days: once a month, the evening before the 13th', () {
    final plan = fastingFrom(1448, 4, 5, {FastingAlert.whiteDays});
    expect(plan.length, 1);
    expect(fastDay(plan.single), (month: 4, day: 13));
  });

  test('Arafah, and never a fast on Eid or the days of Tashreeq', () {
    final plan = fastingFrom(1448, 12, 1, FastingAlert.values.toSet());
    expect(plan.where((a) => a.kind == AlertKind.arafah).map(fastDay), [(month: 12, day: 9)]);
    for (final a in plan) {
      final d = fastDay(a);
      expect(d.month == 12 && d.day >= 10 && d.day <= 13, isFalse, reason: '${a.kind} for 12/${d.day}');
    }
  });

  test('Ashura, ahead of a Monday or Thursday on the same evening', () {
    final plan = fastingFrom(1448, 1, 1, {FastingAlert.arafahAshura, FastingAlert.mondayThursday});
    expect(plan.where((a) => a.kind == AlertKind.ashura).map(fastDay), [(month: 1, day: 10)]);
    expect(plan.where((a) => fastDay(a) == (month: 1, day: 10)).length, 1);
  });

  test('Ramadan: suhoor 40 minutes before Fajr and iftar at Maghrib, every day', () {
    final plan = fastingFrom(1448, 9, 1, FastingAlert.values.toSet());
    final suhoor = plan.where((a) => a.kind == AlertKind.suhoor).toList();
    final iftar = plan.where((a) => a.kind == AlertKind.iftar).toList();
    expect(suhoor.length, PrayerNotificationService.daysAhead);
    expect(iftar.length, PrayerNotificationService.daysAhead);
    final day = DateTime(suhoor.first.time.year, suhoor.first.time.month, suhoor.first.time.day);
    final times = PrayerTimesService.computeFor(coordinates: place, date: day);
    expect(times.entry(PrayerName.fajr).time.difference(suhoor.first.time), const Duration(minutes: 40));
    expect(iftar.first.time, times.entry(PrayerName.maghrib).time);
    // Ramadan is fasted anyway: no Monday, Thursday or White Days reminder in it.
    expect(plan.where((a) => eveKinds.contains(a.kind)), isEmpty);
  });

  test('no reminder to fast on the day of Eid al-Fitr', () {
    final plan = fastingFrom(1448, 9, 25, FastingAlert.values.toSet());
    expect(plan.any((a) => eveKinds.contains(a.kind) && fastDay(a) == (month: 10, day: 1)), isFalse);
    // Suhoor stops with Ramadan.
    for (final a in plan.where((a) => a.kind == AlertKind.suhoor)) {
      expect(IslamicCalendar.of(a.time).hMonth, 9);
    }
  });

  test('ids stay unique with every alert on', () {
    final start = IslamicCalendar.toGregorian(1448, 9, 20);
    final ids = PrayerNotificationService.plan(
      coordinates: place,
      now: start,
      reminderMinutes: 10,
      fridayKahf: true,
      fasting: FastingAlert.values.toSet(),
    ).map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}

/// The longitude where local clock time is roughly solar time.
double _localLongitude() {
  final longitude = DateTime(2026, 6, 15).timeZoneOffset.inMinutes / 4;
  return longitude > 180 ? longitude - 360 : longitude;
}
