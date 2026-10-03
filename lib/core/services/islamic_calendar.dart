import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';

/// The fixed-date occasions of the Islamic year.
enum IslamicEvent {
  newYear(1, 1),
  ashura(1, 10),
  ramadan(9, 1),
  lastTenNights(9, 21),
  eidFitr(10, 1),
  dhulHijjah(12, 1),
  arafah(12, 9),
  eidAdha(12, 10);

  const IslamicEvent(this.month, this.day);

  final int month;
  final int day;
}

@immutable
class UpcomingEvent {
  const UpcomingEvent(this.event, this.date, this.hijriYear);

  final IslamicEvent event;
  final DateTime date;
  final int hijriYear;

  int daysFrom(DateTime today) =>
      date.difference(DateTime(today.year, today.month, today.day)).inDays;
}

/// Hijri dates, with the user's day adjustment applied in exactly one place.
///
/// The `hijri` package follows the Umm al-Qura calendar; local moon sighting
/// can put a month a day either side, so the user may shift every Hijri date
/// by up to two days.
abstract final class IslamicCalendar {
  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The Hijri date of Gregorian [date].
  static HijriCalendar of(DateTime date, {int offset = 0}) =>
      HijriCalendar.fromDate(_date(date).add(Duration(days: offset)));

  /// The Gregorian date of a Hijri date.
  static DateTime toGregorian(int year, int month, int day, {int offset = 0}) =>
      _date(HijriCalendar().hijriToGregorian(year, month, day))
          .subtract(Duration(days: offset));

  static int daysInMonth(int year, int month) =>
      HijriCalendar().getDaysInMonth(year, month);

  /// The White Days, traditionally fasted: the 13th to 15th of each month.
  static bool isWhiteDay(int hijriDay) => hijriDay >= 13 && hijriDay <= 15;

  /// Events falling on a given Hijri day.
  static List<IslamicEvent> eventsOn(int month, int day) =>
      [for (final e in IslamicEvent.values) if (e.month == month && e.day == day) e];

  /// The next [count] events from [today], soonest first. Today's event counts.
  static List<UpcomingEvent> upcoming(DateTime today, {int offset = 0, int count = 5}) {
    final start = _date(today);
    final year = of(start, offset: offset).hYear;
    final all = <UpcomingEvent>[
      for (final y in [year, year + 1])
        for (final e in IslamicEvent.values)
          UpcomingEvent(e, toGregorian(y, e.month, e.day, offset: offset), y),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return all.where((u) => !u.date.isBefore(start)).take(count).toList();
  }

  /// The day of Ramadan, or null outside it.
  static int? ramadanDay(DateTime date, {int offset = 0}) {
    final h = of(date, offset: offset);
    return h.hMonth == 9 ? h.hDay : null;
  }
}
