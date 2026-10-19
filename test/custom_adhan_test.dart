import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/constants/muezzins.dart';
import 'package:sakina/core/services/notification_refresh.dart';
import 'package:sakina/core/services/prayer_notification_service.dart';
import 'package:sakina/core/services/prayer_times_service.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/core/state/settings_cubit.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/settings/muezzin_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _makkah = CustomSound('content://media/external/audio/media/41', 'Makkah adhan');
const _fajr = CustomSound('content://media/external/audio/media/42', 'Makkah fajr');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sakina/sounds');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  var exists = true;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
    calls.clear();
    exists = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'canPickFile' => true,
        'pickFile' => _makkah.toJson(),
        'pickSystem' => _fajr.toJson(),
        'exists' => exists,
        _ => null,
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('Muezzin.custom', () {
    test('each recording gets a channel of its own, the same every run', () {
      final a = Muezzins.custom(_makkah);
      expect(a.channel, startsWith(Muezzin.customChannelPrefix));
      expect(Muezzins.custom(_makkah).channel, a.channel);
      expect(Muezzins.custom(_fajr).channel, isNot(a.channel));
      // No separate Fajr recording: Fajr uses the same channel.
      expect(a.fajrChannel, a.channel);
      expect(Muezzins.custom(_makkah, _fajr).fajrChannel, Muezzins.custom(_fajr).channel);
    });

    test('Fajr tries its own recording, then the main one, then the defaults', () {
      final m = Muezzins.custom(_makkah, _fajr);
      expect(
        PrayerNotificationService.channelsFor(AlertKind.prayer, PrayerName.fajr, PrayerSound.adhan, m),
        [m.fajrChannel, m.channel, PrayerNotificationService.fajrAdhanChannel, PrayerNotificationService.adhanChannel, PrayerNotificationService.standardChannel],
      );
      expect(
        PrayerNotificationService.channelsFor(AlertKind.prayer, PrayerName.asr, PrayerSound.adhan, m).first,
        m.channel,
      );
    });
  });

  group('SettingsCubit.setCustomAdhan', () {
    test('choosing a recording selects it, and it survives a restart', () async {
      final cubit = SettingsCubit()..load();
      await cubit.setCustomAdhan(_makkah);
      await cubit.setCustomAdhan(_fajr, fajr: true);
      expect(cubit.state.muezzin.uri, _makkah.uri);
      expect(cubit.state.muezzin.fajrUri, _fajr.uri);

      final again = SettingsCubit()..load();
      expect(again.state.muezzinId, Muezzins.customId);
      expect(again.state.customAdhan, _makkah);
      expect(again.state.customFajrAdhan, _fajr);
    });

    test('removing it goes back to the default adhan', () async {
      final cubit = SettingsCubit()..load();
      await cubit.setCustomAdhan(_makkah);
      await cubit.setCustomAdhan(_fajr, fajr: true);
      await cubit.setCustomAdhan(null);
      expect(cubit.state.muezzin, Muezzins.standard);
      expect(cubit.state.customFajrAdhan, isNull);
      expect((SettingsCubit()..load()).state.muezzin, Muezzins.standard);
    });

    test('a replaced or removed recording is released, one still in use is not', () async {
      final cubit = SettingsCubit()..load();
      await cubit.setCustomAdhan(_makkah);
      await cubit.setCustomAdhan(_makkah, fajr: true);
      calls.clear();
      await cubit.setCustomAdhan(_fajr);
      // Still the Fajr recording, so kept.
      expect(calls.where((c) => c.method == 'release'), isEmpty);
      await cubit.setCustomAdhan(null);
      expect(
        calls.where((c) => c.method == 'release').map((c) => (c.arguments as Map)['uri']).toSet(),
        {_makkah.uri, _fajr.uri},
      );
    });

    test('a deleted recording is not scheduled', () async {
      final cubit = SettingsCubit()..load();
      await cubit.setCustomAdhan(_makkah);
      expect((await NotificationRefresh.playableMuezzin(cubit.state)).isCustom, isTrue);
      exists = false;
      expect(await NotificationRefresh.playableMuezzin(cubit.state), Muezzins.standard);
    });
  });

  testWidgets('the muezzin screen chooses a file and a Fajr sound', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final cubit = SettingsCubit()..load();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MuezzinView(),
        ),
      ),
    );

    await tester.tap(find.text('Choose a recording'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('An audio file'));
    await tester.pumpAndSettle();
    expect(cubit.state.muezzin.uri, _makkah.uri);
    expect(find.text('Makkah adhan'), findsOneWidget);
    expect(find.text('The same recording'), findsOneWidget);

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A sound on the phone'));
    await tester.pumpAndSettle();
    expect(cubit.state.customFajrAdhan, _fajr);
    expect(find.text('Makkah fajr'), findsOneWidget);

    // Back to a bundled voice keeps the recording for later.
    await tester.tap(find.text('Short adhan'));
    await tester.pumpAndSettle();
    expect(cubit.state.muezzin.id, 'short');
    expect(cubit.state.customAdhan, _makkah);
  });
}
