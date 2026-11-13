import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/latest_only.dart';

void main() {
  test('jobs take turns', () async {
    final queue = LatestOnly();
    final log = <String>[];
    final gate = Completer<void>();

    final first = queue.run((_) async {
      log.add('a starts');
      await gate.future;
      log.add('a ends');
    });
    await Future<void>.delayed(Duration.zero);
    final second = queue.run((_) async => log.add('b runs'));

    await Future<void>.delayed(Duration.zero);
    expect(log, ['a starts']);
    gate.complete();
    await Future.wait([first, second]);
    expect(log, ['a starts', 'a ends', 'b runs']);
  });

  test('a running job is told when a newer one is waiting, and stops', () async {
    final queue = LatestOnly();
    final scheduled = <String>[];
    final gate = Completer<void>();

    // Like a rebuild that began while notifications were on...
    final on = queue.run((superseded) async {
      scheduled.add('fajr');
      await gate.future;
      if (superseded()) return;
      scheduled.add('dhuhr');
    });
    // ...overtaken by the one that turns them off.
    final off = queue.run((_) async => scheduled.clear());

    gate.complete();
    await Future.wait([on, off]);
    expect(scheduled, isEmpty);
  });

  test('of several waiting, only the newest runs', () async {
    final queue = LatestOnly();
    final ran = <int>[];
    final gate = Completer<void>();

    final all = [
      queue.run((_) => gate.future),
      for (var i = 1; i <= 3; i++) queue.run((_) async => ran.add(i)),
    ];
    gate.complete();
    await Future.wait(all);
    expect(ran, [3]);
  });

  test('a job that fails does not hold up the next', () async {
    final queue = LatestOnly();
    final failed = queue.run((_) async => throw StateError('no'));
    await expectLater(failed, throwsStateError);

    var ran = false;
    await queue.run((_) async => ran = true);
    expect(ran, isTrue);
  });
}
