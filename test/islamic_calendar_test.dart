import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/islamic_calendar.dart';

void main() {
  test('a Gregorian date converts to the expected Hijri date', () {
    // 1 Ramadan 1447 fell on 18 February 2026 in Umm al-Qura.
    final h = IslamicCalendar.of(DateTime(2026, 2, 18));
    expect((h.hYear, h.hMonth, h.hDay), (1447, 9, 1));
  });

  test('conversion round-trips', () {
    final g = IslamicCalendar.toGregorian(1447, 12, 10);
    final back = IslamicCalendar.of(g);
    expect((back.hYear, back.hMonth, back.hDay), (1447, 12, 10));
  });

  test('the adjustment shifts every Hijri date by whole days', () {
    final plain = IslamicCalendar.of(DateTime(2026, 2, 18));
    final shifted = IslamicCalendar.of(DateTime(2026, 2, 18), offset: -1);
    expect(plain.hDay, 1);
    expect(shifted.hMonth, 8); // the day before 1 Ramadan is still Sha'ban
  });

  test('the adjustment applies the same way in both directions', () {
    final g = IslamicCalendar.toGregorian(1447, 9, 1, offset: 1);
    final h = IslamicCalendar.of(g, offset: 1);
    expect((h.hMonth, h.hDay), (9, 1));
  });

  test('months are 29 or 30 days', () {
    for (var m = 1; m <= 12; m++) {
      expect(IslamicCalendar.daysInMonth(1447, m), inInclusiveRange(29, 30));
    }
  });

  test('upcoming events are in order, from today, and include the Eids', () {
    final today = DateTime(2026, 1, 1);
    final next = IslamicCalendar.upcoming(today, count: 8);
    expect(next, hasLength(8));
    for (var i = 1; i < next.length; i++) {
      expect(next[i].date.isBefore(next[i - 1].date), isFalse);
    }
    expect(next.every((e) => !e.date.isBefore(today)), isTrue);
    expect(next.map((e) => e.event), containsAll([IslamicEvent.eidFitr, IslamicEvent.eidAdha]));
  });

  test('an event today is still upcoming, at zero days', () {
    final eid = IslamicCalendar.toGregorian(1447, 10, 1);
    final first = IslamicCalendar.upcoming(eid).first;
    expect(first.event, IslamicEvent.eidFitr);
    expect(first.daysFrom(eid), 0);
  });

  test('the White Days are the 13th to 15th', () {
    expect([12, 13, 14, 15, 16].map(IslamicCalendar.isWhiteDay), [false, true, true, true, false]);
  });

  test('ramadanDay is set only in Ramadan', () {
    expect(IslamicCalendar.ramadanDay(DateTime(2026, 2, 20)), 3);
    expect(IslamicCalendar.ramadanDay(DateTime(2026, 6, 1)), isNull);
  });
}
