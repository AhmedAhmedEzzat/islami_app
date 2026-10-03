import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'l10n/gen/app_localizations.dart';

import 'core/constants/prefs_keys.dart';
import 'core/state/bookmarks_cubit.dart';
import 'core/state/quran_player_cubit.dart';
import 'core/state/radio_cubit.dart';
import 'core/services/prayer_notification_service.dart';
import 'core/services/hadeth_favourites.dart';
import 'core/services/quran_meta.dart';
import 'core/services/shared_prefs_helper.dart';
import 'core/state/settings_cubit.dart';
import 'core/state/settings_state.dart';
import 'core/theme/app_theme.dart';
import 'modules/layout/layout_view.dart';
import 'modules/layout/onboarding/on_boarding_screen.dart';
import 'modules/splash/splash_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageServices.init();
  // Required before DateFormat can render Arabic month and day names.
  await initializeDateFormatting();

  // Loaded before runApp so the first frame is already in the right theme.
  final settings = SettingsCubit()..load();

  // Juz, hizb, page and sajda data: small, and the mushaf needs it on its
  // first frame.
  await QuranMeta.load();
  // Its notifier was built before storage was ready.
  HadethFavourites.reload();
  await PrayerNotificationService.init();
  // Recitation and radio are "music" to the OS: they pause for a phone call
  // and resume after, and other apps duck rather than talk over them.
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    debugPrint('Audio session not configured: $e');
  }
  // Top up the rolling schedule on every launch. Not awaited: it must not hold
  // up the first frame.
  _reschedule(settings.state);
  final isFirstTime = LocalStorageServices.getBool(PrefsKeys.firstTime) ?? true;

  runApp(SakinaApp(settings: settings, isFirstTime: isFirstTime));
}

/// The phone's language when the app has no override of its own.
Locale _effectiveLocale(SettingsState state) =>
    state.locale ?? WidgetsBinding.instance.platformDispatcher.locale;

void _reschedule(SettingsState state) {
  PrayerNotificationService.reschedule(
    enabled: state.prayerNotifications,
    locale: _effectiveLocale(state),
    config: state.prayerConfig,
    prayers: state.notifiedPrayers,
    reminderMinutes: state.reminderMinutes,
    fridayKahf: state.fridayKahf,
  );
}

class SakinaApp extends StatelessWidget {
  const SakinaApp({
    super.key,
    required this.settings,
    required this.isFirstTime,
  });

  final SettingsCubit settings;
  final bool isFirstTime;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>.value(value: settings),
        // Owned above the tabs so playback survives switching between them.
        BlocProvider<RadioCubit>(create: (_) => RadioCubit()),
        BlocProvider<BookmarksCubit>(create: (_) => BookmarksCubit()..load()),
        BlocProvider<QuranPlayerCubit>(
          create: (ctx) {
            final radio = ctx.read<RadioCubit>();
            final player = QuranPlayerCubit(radio: radio);
            // Mutual exclusion both ways: the player already stops the radio,
            // and this stops the player when a station starts.
            radio.onBeforePlay = player.stop;
            return player;
          },
          lazy: false,
        ),
      ],
      child: BlocListener<SettingsCubit, SettingsState>(
        // Anything that changes what or when a notification says.
        listenWhen: (a, b) =>
            a.prayerNotifications != b.prayerNotifications ||
            a.prayerConfig != b.prayerConfig ||
            a.locale != b.locale ||
            !setEquals(a.notifiedPrayers, b.notifiedPrayers) ||
            a.reminderMinutes != b.reminderMinutes ||
            a.fridayKahf != b.fridayKahf,
        listener: (_, state) => _reschedule(state),
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            // hijri keeps its language in a mutable global, so it has to be set
            // whenever the resolved locale changes. setLocal throws on a locale
            // it does not ship, so anything else falls back to English.
            final languageCode =
                state.locale?.languageCode ??
                WidgetsBinding.instance.platformDispatcher.locale.languageCode;
            HijriCalendar.setLocal(
              HijriCalendar.supportedLocales.contains(languageCode)
                  ? languageCode
                  : 'en',
            );

            return MaterialApp(
              title: 'Sakina',
              locale: state.locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: state.themeMode,
              initialRoute: isFirstTime
                  ? OnBoardingScreen.routeName
                  : SplashView.routeName,
              routes: {
                SplashView.routeName: (_) => const SplashView(),
                OnBoardingScreen.routeName: (_) => const OnBoardingScreen(),
                LayoutView.routeName: (_) => const LayoutView(),
              },
            );
          },
        ),
      ),
    );
  }
}
