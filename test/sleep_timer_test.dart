import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/sleep_timer.dart';

void main() {
  tearDown(SleepTimer.cancel);

  // testWidgets runs on a fake clock, so minutes pass instantly.
  testWidgets('fires once the time is up, then clears itself', (tester) async {
    var fired = 0;
    SleepTimer.onFire = () => fired++;
    SleepTimer.start(const Duration(minutes: 15));
    await tester.pump(const Duration(minutes: 14));
    expect(fired, 0);
    expect(SleepTimer.setting.value, isNotNull);
    await tester.pump(const Duration(minutes: 2));
    expect(fired, 1);
    expect(SleepTimer.setting.value, isNull);
  });

  testWidgets('cancelling stops it from firing', (tester) async {
    var fired = 0;
    SleepTimer.onFire = () => fired++;
    SleepTimer.start(const Duration(minutes: 1));
    SleepTimer.cancel();
    await tester.pump(const Duration(minutes: 5));
    expect(fired, 0);
  });

  test('end of sura is taken once, by the player', () {
    SleepTimer.stopAtEndOfSura();
    expect(SleepTimer.takeEndOfSura(), isTrue);
    expect(SleepTimer.takeEndOfSura(), isFalse);
    SleepTimer.start(const Duration(minutes: 30));
    expect(SleepTimer.takeEndOfSura(), isFalse, reason: 'a timed sleep ignores the sura end');
  });

  test('remaining time counts down and never goes negative', () {
    final now = DateTime(2026, 1, 1, 22);
    final s = SleepSetting.at(now.add(const Duration(minutes: 10)));
    expect(s.remaining(now.add(const Duration(minutes: 4))), const Duration(minutes: 6));
    expect(s.remaining(now.add(const Duration(hours: 1))), Duration.zero);
  });
}
