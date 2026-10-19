import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/more/names_learn_view.dart';
import 'package:sakina/modules/more/names_view.dart';
import 'package:sakina/core/services/names_learning.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Loaded once, outside any test's fake clock: a future cached inside one
  // widget test never completes in the next.
  late List<AllahName> names;
  setUpAll(() async => names = await AllahName.load());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
  });

  test('learnt names are remembered', () async {
    await NamesLearning.setLearned(1, true);
    await NamesLearning.setLearned(99, true);
    await NamesLearning.setLearned(1, false);
    expect(NamesLearning.learned(), {99});
    await NamesLearning.reset();
    expect(NamesLearning.learned(), isEmpty);
  });

  test('cards not yet learnt come first', () {
    final order = NamesLearning.cardOrder(99, {1, 2, 3}, Random(1));
    expect(order, hasLength(99));
    expect(order.toSet(), hasLength(99));
    expect(order.skip(96).toSet(), {0, 1, 2});
  });

  for (final kind in NameQuizKind.values) {
    test('a $kind quiz has ten distinct questions, each with four choices and its answer', () {
      for (var seed = 0; seed < 50; seed++) {
        final quiz = NamesLearning.quiz(99, kind, Random(seed));
        expect(quiz, hasLength(10));
        expect(quiz.map((q) => q.prompt).toSet(), hasLength(10));
        for (final q in quiz) {
          expect(q.choices.toSet(), hasLength(4));
          expect(q.choices, contains(q.answer));
          if (kind == NameQuizKind.next) {
            expect(q.answer, q.prompt + 1);
            expect(q.choices, isNot(contains(q.prompt)));
          } else {
            expect(q.answer, q.prompt);
          }
        }
      }
    });
  }

  Widget host(Locale locale) => MaterialApp(
    locale: locale,
    localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: NamesLearnView(random: Random(7), preloaded: names),
  );

  testWidgets('a card turns over to the meaning and can be marked learnt', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('0 of 99 learnt'), findsOneWidget);
    await tester.tap(find.text('Tap to turn the card').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('I know it'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 99 learnt'), findsOneWidget);
    expect(NamesLearning.learned(), hasLength(1));
  });

  testWidgets('a quiz runs ten questions and gives a score', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(const Locale('ar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختبار'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      expect(find.text('أي اسم يأتي بعده؟'), findsOneWidget);
      await tester.tap(find.byType(InkWell).at(1));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('من 10'), findsOneWidget);
    expect(find.text('جولة أخرى'), findsOneWidget);
  });
}
