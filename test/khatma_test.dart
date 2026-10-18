import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/khatma.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final start = DateTime(2026, 3, 1);
  KhatmaPlan plan({int days = 30, int furthest = 0}) =>
      KhatmaPlan(start: start, days: days, furthest: furthest);

  test('a 30-day plan reads about 20 pages a day and ends on page 604', () {
    final p = plan();
    expect(p.targetFor(0), 21);
    expect(p.targetFor(29), 604);
    expect(p.today(start), (from: 1, to: 21));
  });

  test("today's portion starts where the reader stopped, behind or ahead", () {
    final day5 = start.add(const Duration(days: 4, hours: 20));
    expect(plan(furthest: 30).today(day5), (from: 31, to: 101));
    expect(plan(furthest: 120).pagesLeftToday(day5), 0);
  });

  test('days are counted by the calendar and stop at the last day', () {
    final p = plan(days: 7);
    expect(p.dayIndex(DateTime(2026, 3, 1, 23, 59)), 0);
    expect(p.dayIndex(DateTime(2026, 3, 2, 0, 1)), 1);
    expect(p.dayIndex(DateTime(2026, 5, 1)), 6);
  });

  test('survives a round trip through storage, and rejects junk', () {
    final p = plan(days: 15, furthest: 42);
    expect(KhatmaPlan.fromJson(p.toJson()), p);
    expect(KhatmaPlan.fromJson({'days': 'x'}), isNull);
    expect(KhatmaPlan.fromJson(null), isNull);
  });

  group('Khatma', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageServices.init();
      Khatma.reload();
    });

    test('only the next page in order counts as read', () async {
      await Khatma.start(30, now: start);
      expect(Khatma.notePage(1), isFalse);
      Khatma.notePage(2);
      Khatma.notePage(300); // jumped ahead to look something up
      expect(Khatma.notifier.value!.furthest, 2);
    });

    test('the last page completes it, and the plan persists', () async {
      await Khatma.start(7, now: start);
      for (var p = 1; p < KhatmaPlan.pages; p++) {
        Khatma.notePage(p);
      }
      expect(Khatma.notePage(KhatmaPlan.pages), isTrue);
      await Future<void>.delayed(Duration.zero);
      Khatma.reload();
      expect(Khatma.notifier.value!.isComplete, isTrue);
    });
  });
}
