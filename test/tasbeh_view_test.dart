import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/layout/tasbeh/tasbeh_view.dart';

/// Locale is pinned so assertions cannot flip with the host's language.
Widget _wrap() => const MaterialApp(
  locale: Locale('en'),
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: TasbehView()),
);

/// Reads the counter without depending on how it is laid out or worded.
String _count(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(TasbehView.countValueKey)).data!;

String _rounds(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(TasbehView.roundsKey)).data!;

Future<void> _tapCounter(WidgetTester tester, {int times = 1}) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byKey(TasbehView.counterKey));
    await tester.pump();
  }
}

void main() {
  testWidgets('counter increments on tap', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(_count(tester), '0');

    await _tapCounter(tester);
    expect(_count(tester), '1');
  });

  testWidgets('a round is 33 counts, then it advances to the next zikr',
      (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('سُبْحَانَ اللَّه'), findsWidgets);

    // 33 taps completes one full round. The counter used to run to 34.
    await _tapCounter(tester, times: 33);

    expect(_count(tester), '0');
    expect(_rounds(tester), '1 round completed');
    expect(find.text('الْـحَمْدُ لِلَّه'), findsWidgets);
  });

  testWidgets('reset clears the count only after confirmation',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _tapCounter(tester, times: 40);
    expect(_count(tester), '7');

    // Cancelling must leave the count alone.
    await tester.tap(find.byKey(TasbehView.resetKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(_count(tester), '7');

    await tester.tap(find.byKey(TasbehView.resetKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TasbehView.resetConfirmKey));
    await tester.pumpAndSettle();

    expect(_count(tester), '0');
    expect(_rounds(tester), 'No rounds yet');
    expect(find.text('سُبْحَانَ اللَّه'), findsWidgets);
  });

  testWidgets('undo steps back a count', (tester) async {
    await tester.pumpWidget(_wrap());
    await _tapCounter(tester, times: 3);
    expect(_count(tester), '3');

    await tester.tap(find.byKey(TasbehView.undoKey));
    await tester.pump();
    expect(_count(tester), '2');
  });

  testWidgets('undo rolls back across a completed round', (tester) async {
    await tester.pumpWidget(_wrap());
    await _tapCounter(tester, times: 33);
    expect(_count(tester), '0');
    expect(_rounds(tester), '1 round completed');

    await tester.tap(find.byKey(TasbehView.undoKey));
    await tester.pump();

    expect(_count(tester), '32');
    expect(_rounds(tester), 'No rounds yet');
    expect(find.text('سُبْحَانَ اللَّه'), findsWidgets);
  });

  testWidgets('undo is disabled at zero', (tester) async {
    await tester.pumpWidget(_wrap());
    final undo = tester.widget<TextButton>(find.byKey(TasbehView.undoKey));
    expect(undo.onPressed, isNull);
  });

  testWidgets('picking a different zikr resets the count for it',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _tapCounter(tester, times: 5);
    expect(_count(tester), '5');

    await tester.tap(find.widgetWithText(ChoiceChip, 'اللَّهُ أَكْبَر'));
    await tester.pump();

    expect(_count(tester), '0');
  });
}
