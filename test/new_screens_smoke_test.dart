import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/recent_suras.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/core/state/bookmarks_cubit.dart';
import 'package:sakina/core/state/verse_notes_cubit.dart';
import 'package:sakina/core/state/quran_player_cubit.dart';
import 'package:sakina/core/state/radio_cubit.dart';
import 'package:sakina/core/state/settings_cubit.dart';
import 'package:sakina/core/theme/app_theme.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/home/home_view.dart';
import 'package:sakina/modules/more/duas_view.dart';
import 'package:sakina/modules/more/names_view.dart';
import 'package:sakina/modules/more/calendar_view.dart';
import 'package:sakina/modules/layout/hadeth/hadeth_view.dart';
import 'package:sakina/modules/layout/tasbeh/tasbeh_view.dart';
import 'package:sakina/modules/layout/azkar/azkar_tab_view.dart';
import 'package:sakina/modules/layout/azkar/azkar_view.dart';
import 'package:sakina/modules/layout/time/time_view.dart';
import 'package:sakina/modules/layout/time/qibla_view.dart';
import 'package:sakina/modules/layout/time/timetable_view.dart';
import 'package:sakina/modules/layout/quran/quran_view.dart';
import 'package:sakina/modules/layout/onboarding/on_boarding_screen.dart';
import 'package:sakina/modules/layout/radio/radio_view.dart';
import 'package:sakina/modules/settings/muezzin_view.dart';
import 'package:sakina/core/services/prayer_times_service.dart';

import 'package:sakina/modules/layout/time/tracker_view.dart';
import 'package:sakina/modules/more/date_converter_view.dart';
import 'package:sakina/modules/more/hifz_view.dart';
import 'package:sakina/modules/more/names_learn_view.dart';
import 'package:sakina/modules/more/listen_view.dart';
import 'package:sakina/modules/more/more_view.dart';
import 'package:sakina/modules/more/zakat_view.dart';
import 'package:sakina/modules/settings/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The screens laid out at the size of the target phone (SM-A528B:
/// 1080×2400 at 2.625) with its 1.1 font scale, and on a small phone (360×640)
/// with the font set to large, in both languages and both themes. Any
/// RenderFlex overflow is reported as a test failure.
Widget _host(Widget page, Locale locale, ThemeData theme, double fontScale) =>
    MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()..load()),
        BlocProvider<RadioCubit>(create: (_) => RadioCubit()),
        BlocProvider<BookmarksCubit>(create: (_) => BookmarksCubit()),
        BlocProvider<VerseNotesCubit>(create: (_) => VerseNotesCubit()),
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
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(fontScale)),
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
    'Listen': () => const ListenView(),
    'Memorisation': () => const HifzView(),
    'Date converter': () => const DateConverterView(),
    'Prayer tracker': () => const TrackerView(),
    'Learn the Names': () => const NamesLearnView(),
    'Duas': () => const DuasView(),
    'Names': () => const NamesView(),
    'Calendar': () => const CalendarView(),
    'Hadeth': () => const HadethView(),
    'Tasbeh': () => const TasbehView(),
    'AzkarTab': () => const AzkarTabView(),
    'Azkar1': () => const AzkarView(chapterId: 1),
    'Time': () => const TimeView(),
    'Qibla': () => QiblaView(location: PrayerTimesService.currentLocation()),
    'Timetable': () =>
        TimetableView(location: PrayerTimesService.currentLocation()),
    'Quran': () => const QuranView(),
    'Onboarding': () => const OnBoardingScreen(),
    'Radio': () => const RadioView(),
    'Muezzin': () => const MuezzinView(),
  };

  const phones = [
    (name: '', size: Size(1080, 2400), pixelRatio: 2.625, fontScale: 1.1),
    (
      name: ' on a small phone with a large font',
      size: Size(720, 1280),
      pixelRatio: 2.0,
      fontScale: 1.3,
    ),
  ];

  for (final phone in phones) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final dark in [false, true]) {
        // The themes differ in colour, not in layout: once is enough.
        if (dark && phone != phones.first) continue;
        for (final MapEntry(key: name, value: build) in pages.entries) {
          testWidgets(
            '$name lays out in ${locale.languageCode}${dark ? ' dark' : ''}${phone.name}',
            (tester) async {
              tester.view.physicalSize = phone.size;
              tester.view.devicePixelRatio = phone.pixelRatio;
              addTearDown(tester.view.reset);

              await tester.pumpWidget(
                _host(
                  build(),
                  locale,
                  dark ? AppTheme.dark : AppTheme.light,
                  phone.fontScale,
                ),
              );
              await _pump(tester);

              // Scroll to the bottom so lazily built rows get laid out too.
              final scrollable = find.byType(Scrollable);
              if (scrollable.evaluate().isNotEmpty) {
                await tester.fling(
                  scrollable.first,
                  const Offset(0, -3000),
                  3000,
                );
                await _pump(tester);
              }
              // Overflows are reported by the framework itself, with the
              // offending widget, and fail the test.
            },
          );
        }
      }
    }
  }
}
