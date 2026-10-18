import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/hifz.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/more/hifz_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
  });

  final monday = DateTime(2026, 10, 19, 21, 30);
  DateTime day(int d) => DateTime(2026, 10, 19 + d, 8);

  test('a memorised sura is due the next day, then further out when easy', () async {
    await Hifz.setStatus(112, HifzStatus.memorised, now: monday);
    expect(Hifz.dueBy(day(0)), isEmpty);
    expect(Hifz.dueBy(day(1)), [112]);

    var today = day(1);
    final gaps = <int>[];
    for (var i = 0; i < 7; i++) {
      await Hifz.revised(112, easy: true, now: today);
      final due = Hifz.of(112)!.due!;
      gaps.add(DateTime.utc(due.year, due.month, due.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays);
      today = due;
    }
    // Capped at a month.
    expect(gaps, [2, 4, 7, 14, 30, 30, 30]);
  });

  test('a hard revision brings it back tomorrow', () async {
    await Hifz.setStatus(67, HifzStatus.memorised, now: monday);
    await Hifz.revised(67, easy: true, now: day(1));
    await Hifz.revised(67, easy: true, now: day(3));
    await Hifz.revised(67, easy: false, now: day(7));
    expect(Hifz.of(67)!.due, DateTime(2026, 10, 27));
  });

  test('overdue suras come first, and learning ones are never due', () async {
    await Hifz.setStatus(1, HifzStatus.memorised, now: day(-5));
    await Hifz.setStatus(114, HifzStatus.memorised, now: day(-2));
    await Hifz.setStatus(36, HifzStatus.learning, now: day(-9));
    expect(Hifz.dueBy(day(0)), [1, 114]);
    expect(Hifz.count(HifzStatus.memorised), 2);
    expect(Hifz.count(HifzStatus.learning), 1);
    expect(Hifz.memorisedVerses(), 7 + 6);
  });

  test('re-marking a sura memorised keeps its schedule; clearing removes it', () async {
    await Hifz.setStatus(2, HifzStatus.memorised, now: day(0));
    await Hifz.revised(2, easy: true, now: day(1));
    await Hifz.setStatus(2, HifzStatus.memorised, now: day(5));
    expect(Hifz.of(2)!.step, 1);
    await Hifz.setStatus(2, null);
    expect(Hifz.of(2), isNull);
  });

  test('survives garbage in storage', () async {
    SharedPreferences.setMockInitialValues({'flutter.quran.hifz': '{"x":1,"2":{"s":"nope"},"3":{"s":"learning"}}'});
    await LocalStorageServices.init();
    expect(Hifz.all().keys, [3]);
  });

  testWidgets('the screen marks a sura memorised and revises a due one', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    await Hifz.setStatus(114, HifzStatus.memorised, now: DateTime(now.year, now.month, now.day - 3));

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: HifzView(),
      ),
    );
    expect(find.text('1 sura to revise'), findsOneWidget);
    expect(find.text('2 days overdue'), findsOneWidget);

    await tester.tap(find.text('Revised'));
    await tester.pumpAndSettle();
    expect(find.text('1 sura to revise'), findsNothing);
    expect(Hifz.of(114)!.step, 1);

    await tester.tap(find.text('Al-Fatiha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Memorised').last);
    await tester.pumpAndSettle();
    expect(Hifz.of(1)!.status, HifzStatus.memorised);
    expect(find.textContaining('2 suras memorised'), findsOneWidget);
  });
}
