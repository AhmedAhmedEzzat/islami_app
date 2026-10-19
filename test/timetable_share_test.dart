import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sakina/core/services/prayer_times_service.dart';
import 'package:sakina/modules/layout/time/timetable_view.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('the shared month has a title, the prayer names, and a line a day', () {
    final rows = PrayerTimesService.computeMonth(
      coordinates: Coordinates(30.0444, 31.2357),
      month: DateTime(2026, 2),
    );
    final text = timetableText(
      title: 'Prayer times · Cairo · February 2026',
      rows: rows,
      dayLabel: DateFormat('EEE d', 'en').format,
      time: DateFormat.Hm('en').format,
      prayerName: (p) => p.name,
    );
    final lines = text.split('\n');
    expect(lines.first, 'Prayer times · Cairo · February 2026');
    expect(lines[1], 'fajr · sunrise · dhuhr · asr · maghrib · isha');
    expect(lines.skip(3), hasLength(28));
    expect(lines[3], startsWith('Sun 1:  '));
    // Six times on every day's line.
    expect(RegExp(r'\d\d:\d\d').allMatches(lines[3]), hasLength(6));
  });
}
