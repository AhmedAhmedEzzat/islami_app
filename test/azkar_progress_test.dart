import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakina/core/services/azkar_favourites.dart';
import 'package:sakina/core/services/azkar_progress.dart';
import 'package:sakina/core/services/azkar_service.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/models/zikr_model.dart';
import 'package:sakina/modules/layout/azkar/azkar_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chapter = AzkarChapter(
  id: 28,
  title: 'أذكار النوم',
  items: [
    ZikrModel(id: 1, text: 'أ', count: 3),
    ZikrModel(id: 2, text: 'ب', count: 1),
  ],
);

const _morning = AzkarChapter(
  id: FeaturedAzkar.morningEvening,
  title: 'أذكار الصباح والمساء',
  items: [ZikrModel(id: 3, text: 'ج', count: 1)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
    AzkarFavourites.reload();
  });

  group('AzkarProgress', () {
    final morning = DateTime(2026, 11, 15, 7);

    test('counts are kept for the day', () async {
      await AzkarProgress.save(_chapter, [1, 0], now: morning);
      expect(
        AzkarProgress.remaining(_chapter, now: DateTime(2026, 11, 15, 22)),
        [1, 0],
      );
      expect(AzkarProgress.fraction(_chapter, now: morning), 0.5);
      // A new day starts afresh.
      expect(
        AzkarProgress.remaining(_chapter, now: DateTime(2026, 11, 16, 7)),
        isNull,
      );
    });

    test('the morning and evening adhkar are two sittings a day', () async {
      await AzkarProgress.save(_morning, [0], now: morning);
      expect(
        AzkarProgress.remaining(_morning, now: DateTime(2026, 11, 15, 11, 59)),
        [0],
      );
      expect(
        AzkarProgress.remaining(_morning, now: DateTime(2026, 11, 15, 16)),
        isNull,
      );
    });

    test('what does not fit the chapter is ignored', () async {
      await AzkarProgress.save(_chapter, [1, 0, 0], now: morning);
      expect(AzkarProgress.remaining(_chapter, now: morning), isNull);
      SharedPreferences.setMockInitialValues({
        'flutter.azkar.progress': 'not json',
      });
      await LocalStorageServices.init();
      expect(AzkarProgress.remaining(_chapter, now: morning), isNull);
    });

    test('a count saved above the dhikr\'s own is held to it', () async {
      await AzkarProgress.save(_chapter, [9, 0], now: morning);
      expect(AzkarProgress.remaining(_chapter, now: morning), [3, 0]);
    });

    test(
      'ended sittings of other chapters are dropped on the next save',
      () async {
        await AzkarProgress.save(_morning, [0], now: morning);
        await AzkarProgress.save(_chapter, [
          0,
          0,
        ], now: DateTime(2026, 11, 16, 7));
        final raw = LocalStorageServices.getString('azkar.progress')!;
        expect(raw, isNot(contains('"27"')));
      },
    );

    test('clearing forgets the chapter', () async {
      await AzkarProgress.save(_chapter, [0, 0], now: morning);
      await AzkarProgress.clear(_chapter);
      expect(AzkarProgress.remaining(_chapter, now: morning), isNull);
    });
  });

  group('favourites', () {
    test(
      'make a chapter of their own, in the order of the book, once each',
      () {
        const other = AzkarChapter(
          id: 10,
          title: 'x',
          items: [ZikrModel(id: 2, text: 'ب', count: 1)],
        );
        final fav = AzkarService.favourites([_chapter, other], {2, 1});
        expect(fav.id, AzkarService.favouritesId);
        expect(fav.items.map((z) => z.id), [2, 1]);
      },
    );

    test('are toggled and kept', () async {
      await AzkarFavourites.toggle(5);
      expect(AzkarFavourites.contains(5), isTrue);
      AzkarFavourites.reload();
      expect(AzkarFavourites.contains(5), isTrue);
      await AzkarFavourites.toggle(5);
      expect(AzkarFavourites.contains(5), isFalse);
    });
  });

  Widget app(Widget home) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  // The book is large enough to be decoded off the main isolate, which a
  // widget test's fake clock never lets finish: load it for real first.
  Future<void> loadBook(WidgetTester tester) =>
      tester.runAsync(AzkarService.loadAll);

  testWidgets('a chapter counts down, remembers where it was, and resets', (
    tester,
  ) async {
    await loadBook(tester);
    await tester.pumpWidget(
      app(const AzkarView(chapterId: FeaturedAzkar.sleep)),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 of 13'), findsOneWidget);

    // The second dhikr of "before sleep" is said once: one tap finishes it.
    final second = find.descendant(
      of: find.byType(Card).at(1),
      matching: find.text('1 left'),
    );
    await tester.ensureVisible(second);
    await tester.pumpAndSettle();
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(find.text('1 of 13'), findsOneWidget);

    // Leave and come back: the count is still there.
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpWidget(
      app(const AzkarView(chapterId: FeaturedAzkar.sleep)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 13'), findsOneWidget);

    await tester.tap(_tooltip('Reset counts'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 13'), findsOneWidget);
  });

  testWidgets('the text size can be changed and is kept', (tester) async {
    await loadBook(tester);
    await tester.pumpWidget(
      app(const AzkarView(chapterId: FeaturedAzkar.sleep)),
    );
    await tester.pumpAndSettle();
    await tester.tap(_tooltip('Larger text'));
    await tester.pumpAndSettle();
    expect(LocalStorageServices.getDouble('azkar.textScale'), 1.2);
  });

  testWidgets('a favourite shows in the favourites chapter', (tester) async {
    await loadBook(tester);
    await tester.pumpWidget(
      app(const AzkarView(chapterId: AzkarService.favouritesId)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No favourites yet'), findsOneWidget);

    await tester.pumpWidget(
      app(
        const AzkarView(key: ValueKey('sleep'), chapterId: FeaturedAzkar.sleep),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_tooltip('Add to favourites').first);
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpWidget(
      app(const AzkarView(chapterId: AzkarService.favouritesId)),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 of 1'), findsOneWidget);
  });
}

/// `find.byTooltip` looks for the framework's own Tooltip class, which is not
/// the one `material_ui` builds.
Finder _tooltip(String message) =>
    find.byWidgetPredicate((w) => w is Tooltip && w.message == message);
