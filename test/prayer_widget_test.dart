import 'package:adhan/adhan.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sakina/core/services/prayer_config.dart';
import 'package:sakina/core/services/prayer_times_service.dart';
import 'package:sakina/core/services/prayer_widget.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final cairo = PrayerLocation(coordinates: Coordinates(30.0444, 31.2357), name: 'Cairo');

  Map<String, Object> data(Locale locale, {PrayerLocation? at}) => PrayerWidget.data(
    location: at ?? cairo,
    config: const PrayerConfig(),
    now: DateTime(2026, 6, 15, 13),
    locale: locale,
  );

  test('five prayers a day for two weeks, in order, without sunrise', () {
    final prayers = data(const Locale('en'))['prayers']! as List;
    expect(prayers, hasLength(5 * PrayerWidget.days));
    final times = [for (final p in prayers) (p as Map)['t'] as int];
    expect(times, orderedEquals([...times]..sort()));
    expect([for (final p in prayers.take(5)) (p as Map)['n']], ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']);
  });

  test('names and times come in the app language, with direction', () {
    final ar = data(const Locale('ar'));
    expect(ar['rtl'], isTrue);
    expect(((ar['prayers']! as List).first as Map)['n'], 'الفجر');
    expect(data(const Locale('en'))['rtl'], isFalse);
  });

  test('the default location is named as such', () {
    final fallback = PrayerLocation(coordinates: Coordinates(30.0444, 31.2357), isFallback: true);
    expect(data(const Locale('en'), at: fallback)['place'], isNot('Cairo'));
    expect(data(const Locale('en'))['place'], 'Cairo');
  });
}
