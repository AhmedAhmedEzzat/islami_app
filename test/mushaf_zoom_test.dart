import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakina/core/constants/prefs_keys.dart';
import 'package:sakina/core/services/mushaf_layout.dart';
import 'package:sakina/core/services/quran_meta.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/core/state/settings_cubit.dart';
import 'package:sakina/modules/layout/quran/widgets/madani_mushaf.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final layout = MushafLayout.parse(File('assets/quran/mushaf.json').readAsStringSync());

  Map<int, List<List<String>>> wordsOn(int page) => {
    for (final s in layout.surasOn(page))
      s: [
        for (final (i, line)
            in File('assets/quran/ar/$s.txt').readAsLinesSync().where((l) => l.trim().isNotEmpty).indexed)
          layout.wordsOf(VerseRef(s, i + 1), line.trim()),
      ],
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
  });

  Future<void> pump(WidgetTester tester, int page, double zoom, {ValueChanged<VerseRef>? onVerseTap}) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => SettingsCubit()..load(),
        child: MaterialApp(
          home: Scaffold(
            body: MushafSheet(layout: layout, page: page, words: wordsOn(page), zoom: zoom, onVerseTap: onVerseTap),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The verse numbers shown, which close every verse ending on the page.
  int rosettes(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text)).where((t) => (t.data ?? '').startsWith('۝')).length;

  for (final page in [1, 2, 3, 77, 604]) {
    testWidgets('page $page at 100% fits the screen and does not scroll', (tester) async {
      await pump(tester, page, 1);
      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('page $page enlarged keeps every verse and scrolls', (tester) async {
      await pump(tester, page, 1);
      final printed = rosettes(tester);
      expect(printed, greaterThan(0));

      await pump(tester, page, 1.8);
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsOneWidget);
      expect(rosettes(tester), printed);
    });
  }

  testWidgets('an enlarged page is taller than the screen and its text is larger', (tester) async {
    double fontSize() => tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((t) => t.style?.fontFamily == 'AmiriQuran')
        .style!
        .fontSize!;

    await pump(tester, 3, 1);
    final printed = fontSize();
    await pump(tester, 3, 1.5);
    // At least the size asked for; the margins' width goes to the text too.
    expect(fontSize(), greaterThanOrEqualTo(printed * 1.5));
    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.maxScrollExtent, greaterThan(100));
  });

  testWidgets('a verse can still be opened from an enlarged page', (tester) async {
    VerseRef? tapped;
    await pump(tester, 3, 1.6, onVerseTap: (v) => tapped = v);
    await tester.tap(find.textContaining('۝').first);
    expect(tapped?.sura, 2);
  });

  // The whole mushaf, as the Quran tab shows it, and not just one sheet: its
  // pages are built during layout, where reading the text size with a select
  // used to fail provider's assertion and show an error box on every page in
  // debug builds.
  for (final zoom in [1.0, 1.6]) {
    testWidgets('the mushaf at ${(zoom * 100).round()}% builds its pages without errors', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({PrefsKeys.quranFontScale: zoom});
      await LocalStorageServices.init();
      await tester.pumpWidget(
        BlocProvider(
          create: (_) => SettingsCubit()..load(),
          child: MaterialApp(
            home: Scaffold(body: MadaniMushaf(layout: layout, initialPage: 3)),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(MushafSheet), findsWidgets);
      expect(tester.widget<MushafSheet>(find.byType(MushafSheet).first).zoom, zoom);
    });
  }
}
