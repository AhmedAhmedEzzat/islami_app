import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/daily_deeds.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/home/daily_deeds_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
  });

  final today = DateTime(2026, 10, 19, 15);
  DateTime ago(int n) => DateTime(2026, 10, 19 - n);
  Future<void> doAll(DateTime day) async {
    for (final d in DailyDeeds.visible()) {
      await DailyDeeds.toggle(day, d.id);
    }
  }

  test('the six built-in deeds are on the list to start with', () {
    expect(DailyDeeds.visible().map((d) => d.id), DailyDeeds.builtInIds);
  });

  test('ticks belong to their day', () async {
    await DailyDeeds.toggle(today, 'quran');
    expect(DailyDeeds.doneOn(today), {'quran'});
    expect(DailyDeeds.doneOn(ago(1)), isEmpty);
    await DailyDeeds.toggle(today, 'quran');
    expect(DailyDeeds.doneOn(today), isEmpty);
  });

  test('hidden and custom deeds shape the list', () async {
    await DailyDeeds.setShown('witr', false);
    await DailyDeeds.addCustom('  Call my parents ', now: DateTime(2026));
    final list = DailyDeeds.visible();
    expect(list.map((d) => d.id), isNot(contains('witr')));
    expect(list.last.title, 'Call my parents');
    await DailyDeeds.removeCustom(list.last.id);
    expect(DailyDeeds.custom(), isEmpty);
    expect(DailyDeeds.hidden(), {'witr'});
  });

  test('the streak counts full days back from today, by calendar date', () async {
    await DailyDeeds.setShown('witr', false);
    for (final n in [1, 2, 3]) {
      await doAll(ago(n));
    }
    await doAll(ago(5));
    // Today unfinished does not break the run that reached yesterday.
    expect(DailyDeeds.streak(today), 3);
    await doAll(today);
    expect(DailyDeeds.streak(today), 4);
    // Across the November clock change too.
    final nov = DateTime(2026, 11, 2);
    for (var n = 0; n < 4; n++) {
      await doAll(DateTime(2026, 11, 2 - n));
    }
    expect(DailyDeeds.streak(nov), 4);
  });

  testWidgets('the card ticks a deed and adds one of your own', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: DailyDeedsCard(now: today))),
      ),
    );
    expect(find.textContaining('0 of 6 done'), findsOneWidget);
    await tester.tap(find.text('Read Quran'));
    await tester.pump();
    expect(find.textContaining('1 of 6 done'), findsOneWidget);

    await tester.tap(find.byTooltip('Choose your deeds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add your own'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Call my parents');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(DailyDeeds.custom().single.title, 'Call my parents');
  });
}
