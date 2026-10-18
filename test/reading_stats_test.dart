import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/reading_stats.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 3, 10, 21);
  DateTime ago(int days) => today.subtract(Duration(days: days));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
  });

  test('a page counts once a day, however often it is turned back to', () async {
    await ReadingStats.notePage(5, at: today);
    await ReadingStats.notePage(6, at: today);
    await ReadingStats.notePage(5, at: today);
    expect(ReadingStats.pagesOn(today), 2);
  });

  test('the week adds up the last seven days only', () async {
    await ReadingStats.notePage(1, at: today);
    await ReadingStats.notePage(2, at: ago(6));
    await ReadingStats.notePage(3, at: ago(7));
    expect(ReadingStats.pagesThisWeek(today), 2);
  });

  test('the streak counts back from today, or from yesterday if today is unread', () async {
    for (final d in [1, 2, 3, 5]) {
      await ReadingStats.notePage(10, at: ago(d));
    }
    expect(ReadingStats.streak(today), 3);
    await ReadingStats.notePage(11, at: today);
    expect(ReadingStats.streak(today), 4);
  });

  test('days older than the window are dropped as new ones come in', () async {
    await ReadingStats.notePage(1, at: ago(ReadingStats.keepDays + 5));
    await ReadingStats.notePage(2, at: today);
    expect(ReadingStats.pagesOn(ago(ReadingStats.keepDays + 5)), 0);
    expect(ReadingStats.pagesOn(today), 1);
  });
}
