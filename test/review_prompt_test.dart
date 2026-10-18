import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/review_prompt.dart';

void main() {
  final first = DateTime(2026, 1, 1);

  bool ask({int days = 10, int moments = 3, int asks = 0, DateTime? lastAsked}) => ReviewPrompt.shouldAsk(
    now: first.add(Duration(days: days)),
    firstUse: first,
    lastAsked: lastAsked,
    moments: moments,
    asks: asks,
  );

  test('asks after enough good moments once the app has been in use a while', () {
    expect(ask(), isTrue);
    expect(ask(days: 2), isFalse, reason: 'too new');
    expect(ask(moments: 2), isFalse, reason: 'not enough good moments');
  });

  test('never more often than the gap, nor more than the cap', () {
    expect(ask(days: 100, lastAsked: first.add(const Duration(days: 10))), isFalse);
    expect(ask(days: 140, lastAsked: first.add(const Duration(days: 10))), isTrue);
    expect(ask(asks: ReviewPrompt.maxAsks), isFalse);
  });

  test('without a first-use date it does not ask', () {
    expect(
      ReviewPrompt.shouldAsk(now: first, firstUse: null, lastAsked: null, moments: 9, asks: 0),
      isFalse,
    );
  });
}
