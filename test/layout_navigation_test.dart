import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/core/state/bookmarks_cubit.dart';
import 'package:sakina/core/state/quran_player_cubit.dart';
import 'package:sakina/core/state/radio_cubit.dart';
import 'package:sakina/core/state/settings_cubit.dart';
import 'package:sakina/core/theme/app_theme.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/layout/layout_view.dart';
import 'package:sakina/modules/layout/quran/quran_details_view.dart';
import 'package:sakina/core/constants/prefs_keys.dart';
import 'package:sakina/core/services/recent_suras.dart';
import 'package:sakina/modules/home/home_view.dart';
import 'package:sakina/modules/layout/azkar/azkar_tab_view.dart';
import 'package:sakina/modules/layout/layout_scope.dart';
import 'package:sakina/modules/layout/radio/radio_view.dart';
import 'package:sakina/modules/more/more_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The tab bar is the whole point of the nested navigators: it must survive a
/// push into a tab.
Finder get _tabBar => find.byType(NavigationBar);

/// pumpAndSettle cannot be used here: Home's prayer countdown rebuilds every
/// second and never settles. Opening a
/// sura also awaits a SharedPreferences write before pushing, so a single pump
/// is not enough either.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _app() {
  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()..load()),
      BlocProvider<RadioCubit>(create: (_) => RadioCubit()),
      BlocProvider<BookmarksCubit>(create: (_) => BookmarksCubit()),
      BlocProvider<QuranPlayerCubit>(
        create: (ctx) => QuranPlayerCubit(radio: ctx.read<RadioCubit>()),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LayoutView(),
    ),
  );
}

Finder _tab(String label) =>
    find.descendant(of: _tabBar, matching: find.text(label));

int _selectedTab(WidgetTester tester) =>
    tester.widget<NavigationBar>(_tabBar).selectedIndex;

Future<void> _openFatiha(WidgetTester tester) async {
  await tester.tap(_tab('Quran'));
  await _settle(tester);
  await tester.tap(find.text('Al-Fatiha').first);
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
    RecentSuras.reload();
  });

  testWidgets('starts on Home with the five tabs', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);

    expect(_selectedTab(tester), AppTab.home);
    for (final label in ['Home', 'Quran', 'Prayer', 'Adhkar', 'More']) {
      expect(_tab(label), findsOneWidget, reason: label);
    }
    expect(find.text('Assalamu alaikum'), findsOneWidget);
  });

  testWidgets('opening a sura keeps the tab bar visible', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    await _openFatiha(tester);

    // This is the behaviour the whole change exists for: the detail page is
    // rendered inside the tab, not over the top of the app.
    expect(_tabBar, findsOneWidget);
    expect(find.byType(QuranDetailsView), findsOneWidget);
  });

  testWidgets('switching tabs and back leaves the sura open', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    await _openFatiha(tester);

    await tester.tap(_tab('Adhkar'));
    await _settle(tester);
    expect(find.byType(AzkarTabView), findsOneWidget);

    await tester.tap(_tab('Quran'));
    await _settle(tester);

    // IndexedStack kept the Quran tab's stack alive.
    expect(find.byType(QuranDetailsView), findsOneWidget);
    expect(_tabBar, findsOneWidget);
  });

  testWidgets('system back pops the sura instead of leaving the app',
      (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    await _openFatiha(tester);
    // The list route stays mounted underneath, so assert on the pushed route
    // rather than on the list's text.
    expect(find.byType(QuranDetailsView), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(find.byType(QuranDetailsView), findsNothing);
    expect(find.text('Suras'), findsOneWidget);
    expect(_tabBar, findsOneWidget);
  });

  testWidgets('system back from another tab returns to Home', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);

    await tester.tap(_tab('More'));
    await _settle(tester);
    expect(find.byType(MoreView), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(_selectedTab(tester), AppTab.home);
    expect(find.text('Assalamu alaikum'), findsOneWidget);
  });

  testWidgets('radio opened from More is a page with a way back',
      (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);

    await tester.tap(_tab('More'));
    await _settle(tester);
    await tester.tap(find.text('Quran Radio'));
    await _settle(tester);
    expect(find.byType(RadioView), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(RadioView), findsNothing);
    expect(_selectedTab(tester), AppTab.more);
  });

  testWidgets("Home's continue reading opens the sura in the Quran tab",
      (tester) async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.recentSuraIndex: ['1'],
    });
    await LocalStorageServices.init();
    RecentSuras.reload();

    await tester.pumpWidget(_app());
    await _settle(tester);

    final resume = find.text('Continue where you left off');
    await tester.scrollUntilVisible(
      resume,
      200,
      scrollable: find
          .descendant(of: find.byType(HomeView), matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(resume);
    await _settle(tester);

    expect(_selectedTab(tester), AppTab.quran);
    expect(find.byType(QuranDetailsView), findsOneWidget);
    expect(find.text('Al-Baqarah'), findsWidgets);
  });
}
