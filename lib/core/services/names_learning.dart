import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'shared_prefs_helper.dart';

/// One quiz question: the name at [prompt] and four choices, by index into
/// the list of names, one of which is [answer].
@immutable
class NameQuestion {
  const NameQuestion(this.prompt, this.choices, this.answer);

  final int prompt;
  final List<int> choices;
  final int answer;
}

/// What the quiz asks: a name's meaning, or which name follows it in the
/// list, for learning them in order.
enum NameQuizKind { meaning, next }

/// Learning the 99 Names: which the reader has learnt, and quiz questions.
abstract final class NamesLearning {
  static const String _key = 'names.learned';
  static final ValueNotifier<int> changes = ValueNotifier(0);

  /// Learnt names, by their number (1-99).
  static Set<int> learned() {
    final raw = LocalStorageServices.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return {for (final e in jsonDecode(raw) as List) if (e is int) e};
    } catch (_) {
      return {};
    }
  }

  static Future<void> setLearned(int number, bool learnt) async {
    final set = learned();
    learnt ? set.add(number) : set.remove(number);
    await LocalStorageServices.setString(_key, jsonEncode(set.toList()..sort()));
    changes.value++;
  }

  static Future<void> reset() async {
    await LocalStorageServices.setString(_key, '[]');
    changes.value++;
  }

  /// The order to show the cards in: names not yet learnt first, each group
  /// shuffled.
  static List<int> cardOrder(int count, Set<int> learnt, Random random) {
    final fresh = [for (var i = 0; i < count; i++) if (!learnt.contains(i + 1)) i]..shuffle(random);
    final known = [for (var i = 0; i < count; i++) if (learnt.contains(i + 1)) i]..shuffle(random);
    return [...fresh, ...known];
  }

  /// [length] questions over [count] names, none asked twice. For [NameQuizKind.next]
  /// the last name has nothing after it, so it is never asked.
  static List<NameQuestion> quiz(int count, NameQuizKind kind, Random random, {int length = 10}) {
    final askable = [for (var i = 0; i < (kind == NameQuizKind.next ? count - 1 : count); i++) i]..shuffle(random);
    return [
      for (final prompt in askable.take(length))
        () {
          final answer = kind == NameQuizKind.next ? prompt + 1 : prompt;
          final others = {answer};
          while (others.length < min(4, count)) {
            final c = random.nextInt(count);
            // In "what comes next", the name itself would be a giveaway wrong answer.
            if (kind == NameQuizKind.next && c == prompt) continue;
            others.add(c);
          }
          return NameQuestion(prompt, others.toList()..shuffle(random), answer);
        }(),
    ];
  }
}
