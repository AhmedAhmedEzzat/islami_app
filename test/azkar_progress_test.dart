import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/azkar_progress.dart';
import 'package:sakina/core/services/azkar_service.dart';
import 'package:sakina/core/services/daily_deeds.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/models/zikr_model.dart';
import 'package:sakina/modules/layout/azkar/azkar_index_view.dart';
import 'package:sakina/modules/layout/azkar/azkar_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {double textScale = 1, Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: child,
);

const _chapter = AzkarChapter(
  id: 999,
  title: 'باب',
  items: [ZikrModel(id: 1, text: 'أ', count: 3), ZikrModel(id: 2, text: 'ب', count: 1)],
);

Future<AzkarChapter> _bundled(WidgetTester tester, int id) async =>
    (await tester.runAsync(() => AzkarService.chapter(id)))!;

/// Loads the chapter outside the fake clock, where asset reads complete.
Future<void> _pumpReader(WidgetTester tester, Widget view, {double textScale = 1, Locale? locale}) async {
  await tester.runAsync(AzkarService.loadAll);
  await tester.pumpWidget(_wrap(view, textScale: textScale, locale: locale ?? const Locale('en')));
  await tester.pumpAndSettle();
}

String _counterText(WidgetTester tester, int zikrId) {
  final chip = tester.widget<Chip>(find.byKey(AzkarView.counterKey(zikrId)));
  return (chip.label as Text).data!;
}

Future<void> _tapCard(WidgetTester tester, int zikrId, {int times = 1}) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byKey(AzkarView.cardKey(zikrId)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
    DailyDeeds.changes.value++;
  });

  group('AzkarProgress', () {
    final morning = DateTime(2026, 11, 13, 7);

    test('counts come back within the same day', () async {
      await AzkarProgress.save(999, morning, {1: 1, 2: 0});
      expect(AzkarProgress.remaining(_chapter, DateTime(2026, 11, 13, 22)), {1: 1, 2: 0});
      expect(AzkarProgress.doneCount(_chapter, morning), 1);
    });

    test('a chapter counts as finished only when every dhikr is, this session', () async {
      await AzkarProgress.save(999, morning, {1: 0, 2: 1});
      expect(AzkarProgress.isFinished(999, morning), isFalse);
      await AzkarProgress.save(999, morning, {1: 0, 2: 0});
      expect(AzkarProgress.isFinished(999, morning), isTrue);
      expect(AzkarProgress.isFinished(999, DateTime(2026, 11, 14, 7)), isFalse);
    });

    test('a chapter is due afresh the next day', () async {
      await AzkarProgress.save(999, morning, {1: 0, 2: 0});
      expect(AzkarProgress.remaining(_chapter, DateTime(2026, 11, 14, 7)), {1: 3, 2: 1});
      expect(AzkarProgress.doneCount(_chapter, DateTime(2026, 11, 14, 7)), 0);
    });

    test('the morning and evening adhkar are due again at noon', () async {
      const id = FeaturedAzkar.morningEvening;
      await AzkarProgress.save(id, morning, {75: 0});
      expect(AzkarProgress.load(id, DateTime(2026, 11, 13, 11, 59)), {75: 0});
      expect(AzkarProgress.load(id, DateTime(2026, 11, 13, 12)), isNull);
    });

    test('stored counts are clamped to the dhikr, and unknown ones ignored', () async {
      await AzkarProgress.save(999, morning, {1: 50, 7: 0});
      expect(AzkarProgress.remaining(_chapter, morning), {1: 3, 2: 1});
    });

    test('corrupt storage reads as no progress', () async {
      await LocalStorageServices.setString('azkar.progress.999', '{not json');
      expect(AzkarProgress.load(999, morning), isNull);
    });

    test('finishing the morning or evening adhkar ticks the matching deed once', () async {
      const id = FeaturedAzkar.morningEvening;
      await AzkarProgress.recordFinished(id, morning);
      await AzkarProgress.recordFinished(id, morning);
      expect(DailyDeeds.doneOn(morning), {'morningAdhkar'});
      final evening = DateTime(2026, 11, 13, 18);
      await AzkarProgress.recordFinished(id, evening);
      expect(DailyDeeds.doneOn(evening), {'morningAdhkar', 'eveningAdhkar'});
      // Other chapters are not on the checklist.
      await AzkarProgress.recordFinished(FeaturedAzkar.sleep, evening);
      expect(DailyDeeds.doneOn(evening), hasLength(2));
    });

    test('the text size stays within bounds', () async {
      expect(AzkarProgress.fontScale(), 1);
      await AzkarProgress.setFontScale(5);
      expect(AzkarProgress.fontScale(), AzkarProgress.maxFontScale);
    });
  });

  group('AzkarView', () {
    DateTime clock() => DateTime(2026, 11, 13, 7);

    testWidgets('counts survive leaving the page and coming back', (tester) async {
      final chapter = await _bundled(tester, FeaturedAzkar.sleep);
      final first = chapter.items.first;
      await _pumpReader(tester, AzkarView(chapterId: chapter.id, clock: clock));
      expect(_counterText(tester, first.id), '${first.count} left');

      await _tapCard(tester, first.id);
      expect(_counterText(tester, first.id), '${first.count - 1} left');

      await tester.pumpWidget(const SizedBox());
      await _pumpReader(tester, AzkarView(chapterId: chapter.id, clock: clock));
      expect(_counterText(tester, first.id), '${first.count - 1} left');
    });

    testWidgets('a long-press takes back a count by mistake', (tester) async {
      final chapter = await _bundled(tester, FeaturedAzkar.sleep);
      final first = chapter.items.first;
      await _pumpReader(tester, AzkarView(chapterId: chapter.id, clock: clock));
      await _tapCard(tester, first.id);

      await tester.longPress(find.byKey(AzkarView.cardKey(first.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take back one count'));
      await tester.pumpAndSettle();
      expect(_counterText(tester, first.id), '${first.count} left');
      expect(AzkarProgress.load(chapter.id, clock())?[first.id], first.count);
    });

    testWidgets('reset asks first and clears the saved counts', (tester) async {
      final chapter = await _bundled(tester, FeaturedAzkar.sleep);
      final first = chapter.items.first;
      await _pumpReader(tester, AzkarView(chapterId: chapter.id, clock: clock));
      await _tapCard(tester, first.id);

      await tester.tap(find.byTooltip('Reset counts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_counterText(tester, first.id), '${first.count - 1} left');

      await tester.tap(find.byTooltip('Reset counts'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pumpAndSettle();
      expect(_counterText(tester, first.id), '${first.count} left');
      expect(AzkarProgress.load(chapter.id, clock()), isNull);
    });

    testWidgets('finishing the morning adhkar ticks it on the daily checklist', (tester) async {
      final chapter = await _bundled(tester, FeaturedAzkar.morningEvening);
      // Everything but the last tap of the last dhikr, already read.
      final last = chapter.items.last;
      await AzkarProgress.save(chapter.id, clock(), {for (final z in chapter.items) z.id: z.id == last.id ? 1 : 0});
      await _pumpReader(tester, AzkarView(chapterId: chapter.id, clock: clock));
      expect(find.text('Counting for this morning'), findsOneWidget);

      await tester.scrollUntilVisible(find.byKey(AzkarView.cardKey(last.id)), 400, scrollable: find.byType(Scrollable).first);
      await _tapCard(tester, last.id);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(DailyDeeds.doneOn(clock()), contains('morningAdhkar'));
      expect(find.text('All done. May Allah accept it.'), findsOneWidget);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('a large font and text size fit without overflow (${locale.languageCode})', (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await AzkarProgress.setFontScale(AzkarProgress.maxFontScale);
        await _pumpReader(
          tester,
          const AzkarView(chapterId: FeaturedAzkar.morningEvening),
          textScale: 2,
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('AzkarIndexView', () {
    testWidgets('shows how far each chapter got today', (tester) async {
      final chapter = await _bundled(tester, FeaturedAzkar.sleep);
      await AzkarProgress.save(chapter.id, DateTime.now(), {chapter.items.first.id: 0});
      await _pumpReader(tester, const Scaffold(body: AzkarIndexView(embedded: true)));
      await tester.scrollUntilVisible(find.text(chapter.title), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('1/${chapter.items.length}'), findsOneWidget);
    });

    testWidgets('the daily cards grow with a large font', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await _pumpReader(tester, const Scaffold(body: AzkarIndexView(embedded: true)), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
