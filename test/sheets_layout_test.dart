import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/core/services/sleep_timer.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/home/khatma_card.dart';
import 'package:sakina/modules/layout/widgets/sleep_timer_sheet.dart';
import 'package:sakina/modules/more/hifz_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The bottom sheets on a small phone (360×640) with the font set to large.
/// A sheet is at most nine sixteenths of the screen unless it says otherwise,
/// so a list of options that fits a tall phone can run off a short one, where
/// the framework reports the overflow and fails the test.
Widget _app(Widget home, Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
    child: child!,
  ),
  home: home,
);

Widget _opener(Future<void> Function(BuildContext) open) => Scaffold(
  body: Builder(
    builder: (context) => Center(
      child: TextButton(onPressed: () => open(context), child: const Text('open')),
    ),
  ),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    Future<void> small(WidgetTester tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('the sleep timer sheet fits, with every option, in ${locale.languageCode}', (tester) async {
      await small(tester);
      // A timer running adds "turn off" to the list, the longest it gets.
      SleepTimer.stopAtEndOfSura();
      addTearDown(SleepTimer.cancel);
      await tester.pumpWidget(_app(_opener((c) => showSleepTimerSheet(c, offerEndOfSura: true)), locale));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The last option can be brought into view and used.
      final off = find.byIcon(Icons.timer_off_outlined);
      await tester.ensureVisible(off);
      await tester.pumpAndSettle();
      await tester.tap(off);
      await tester.pumpAndSettle();
      expect(SleepTimer.setting.value, isNull);
    });

    testWidgets('the khatma sheet fits in ${locale.languageCode}', (tester) async {
      await small(tester);
      await tester.pumpWidget(_app(_opener(KhatmaCard.showStartSheet), locale));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsWidgets);
    });

    testWidgets('the memorisation sheet fits in ${locale.languageCode}', (tester) async {
      await small(tester);
      await tester.pumpWidget(_app(const HifzView(), locale));
      await tester.pumpAndSettle();
      final first = find.text(locale.languageCode == 'ar' ? 'الفاتحة' : 'Al-Fatiha');
      await tester.scrollUntilVisible(first, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });
  }
}
