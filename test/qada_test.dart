import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/prayer_times_service.dart';
import 'package:sakina/core/services/qada.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
  });

  test('counts per prayer, and never below zero', () async {
    await Qada.add(PrayerName.fajr, 2);
    await Qada.add(PrayerName.fajr, -5);
    expect(Qada.count(PrayerName.fajr), 0);
    await Qada.add(PrayerName.isha, 1);
    expect(Qada.total, 1);
  });

  test('adding days adds all five prayers for each, never sunrise', () async {
    await Qada.addDays(30);
    expect(Qada.total, 150);
    expect(Qada.count(PrayerName.dhuhr), 30);
    expect(Qada.count(PrayerName.sunrise), 0);
  });
}
