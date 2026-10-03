import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
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
    // Fajr and Dhuhr have passed; Asr, Maghrib and Isha remain today.
    expect(planAt(DateTime(2026, 6, 15, 15)).length, 5 * days - 2);
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
}
