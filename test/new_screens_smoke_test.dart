import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/recent_suras.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/core/state/bookmarks_cubit.dart';
import 'package:sakina/core/state/quran_player_cubit.dart';
import 'package:sakina/core/state/radio_cubit.dart';
import 'package:sakina/core/state/settings_cubit.dart';
import 'package:sakina/core/theme/app_theme.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/home/home_view.dart';
import 'package:sakina/modules/more/more_view.dart';
import 'package:sakina/modules/more/zakat_view.dart';
import 'package:sakina/modules/settings/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The new screens laid out at the size of the target phone (SM-A528B:
/// 1080×2400 at 2.625) with its 1.1 font scale, in both languages and both
/// themes. Any RenderFlex overflow is reported as a test failure.
Widget _host(Widget page, Locale locale, ThemeData theme) => MultiBlocProvider(
  providers: [
    BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()..load()),
    BlocProvider<RadioCubit>(create: (_) => RadioCubit()),
    BlocProvider<BookmarksCubit>(create: (_) => BookmarksCubit()),
    BlocProvider<QuranPlayerCubit>(
      create: (ctx) => QuranPlayerCubit(radio: ctx.read<RadioCubit>()),
    ),
  ],
  child: MaterialApp(
    theme: theme,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.1)),
      child: child!,
    ),
    home: page,
  ),
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'recent-sura-index': ['17'],
    });
    await LocalStorageServices.init();
    RecentSuras.reload();
  });

  final pages = <String, Widget Function()>{
    'Home': () => const HomeView(),
    'More': () => const MoreView(),
    'Zakat': () => const ZakatView(),
    'Settings': () => const SettingsView(),
  };

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final dark in [false, true]) {
      for (final MapEntry(key: name, value: build) in pages.entries) {
        testWidgets('$name lays out in ${locale.languageCode}${dark ? ' dark' : ''}', (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.625;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_host(build(), locale, dark ? AppTheme.dark : AppTheme.light));
          await _pump(tester);

          // Scroll to the bottom so lazily built rows get laid out too.
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.fling(scrollable.first, const Offset(0, -3000), 3000);
            await _pump(tester);
          }
          // Overflows are reported by the framework itself, with the
          // offending widget, and fail the test.
        });
      }
    }
  }
}
