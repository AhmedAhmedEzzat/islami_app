import 'dart:async';

import 'package:adhan/adhan.dart' show Coordinates;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/constants/prefs_keys.dart';
import 'package:sakina/core/services/prayer_times_service.dart';
import 'package:sakina/core/services/qibla_compass.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/core/state/settings_cubit.dart';
import 'package:sakina/core/theme/app_theme.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/layout/time/qibla_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

CompassEvent _event(double heading, {double accuracy = 15}) =>
    CompassEvent.fromList([heading, heading, accuracy]);

void main() {
  group('QiblaCompass', () {
    test('turn needed takes the short way round', () {
      expect(QiblaCompass.turnNeeded(350, 10), 20);
      expect(QiblaCompass.turnNeeded(10, 350), -20);
      expect(QiblaCompass.turnNeeded(136, 136), 0);
      expect(QiblaCompass.turnNeeded(0, 180).abs(), 180);
    });

    test('normalize keeps angles in 0..360', () {
      expect(QiblaCompass.normalize(-10), 350);
      expect(QiblaCompass.normalize(370), 10);
    });

    test('calibration is asked for when the sensor is unsure', () {
      const android = TargetPlatform.android;
      const ios = TargetPlatform.iOS;
      expect(QiblaCompass.needsCalibration(15, platform: android), isFalse);
      expect(QiblaCompass.needsCalibration(30, platform: android), isFalse);
      expect(QiblaCompass.needsCalibration(45, platform: android), isTrue);
      expect(QiblaCompass.needsCalibration(null, platform: android), isTrue);
      expect(QiblaCompass.needsCalibration(10, platform: ios), isFalse);
      expect(QiblaCompass.needsCalibration(40, platform: ios), isTrue);
      expect(QiblaCompass.needsCalibration(-1, platform: ios), isTrue);
    });
  });

  group('HeadingFilter', () {
    test('averages across north instead of swinging through south', () {
      final f = HeadingFilter();
      f.add(358);
      for (var i = 0; i < 20; i++) {
        f.add(i.isEven ? 2 : 358);
      }
      final v = f.value!;
      expect(v < 5 || v > 355, isTrue, reason: 'got $v');
    });

    test('settles on a steady reading and follows a real turn', () {
      final f = HeadingFilter();
      for (var i = 0; i < 30; i++) {
        f.add(90);
      }
      expect(f.value, closeTo(90, 0.01));
      for (var i = 0; i < 30; i++) {
        f.add(200);
      }
      expect(f.value, closeTo(200, 1));
    });

    test('damps a small shake', () {
      final f = HeadingFilter()..add(100);
      f.add(104);
      expect(f.value! - 100, lessThan(2));
    });
  });

  group('QiblaView', () {
    // Cairo; the Qibla is about 136 degrees from there.
    final cairo = PrayerLocation(
      coordinates: Coordinates(30.0444, 31.2357),
      name: 'Cairo, Egypt',
      isManual: true,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.manualLatitude: 30.0444,
        PrefsKeys.manualLongitude: 31.2357,
        PrefsKeys.manualPlaceName: 'Cairo, Egypt',
      });
      await LocalStorageServices.init();
    });

    void tallPhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
    }

    Widget host(Widget page) => BlocProvider<SettingsCubit>(
      create: (_) => SettingsCubit()..load(),
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    );

    testWidgets('says which way to turn, then that the Qibla is ahead', (tester) async {
      tallPhone(tester);
      final compass = StreamController<CompassEvent>();
      addTearDown(compass.close);
      await tester.pumpWidget(host(QiblaView(location: cairo, compassEvents: compass.stream)));
      final qibla = PrayerTimesService.qiblaBearing(cairo.coordinates);

      compass.add(_event(qibla - 40));
      await tester.pump();
      expect(find.text('Turn right 40°'), findsOneWidget);

      // Facing it once the smoothed heading has caught up.
      for (var i = 0; i < 40; i++) {
        compass.add(_event(qibla + 1));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('You are facing the Qibla'), findsOneWidget);

      // A tremble past the entry window does not drop out of facing.
      compass.add(_event(qibla + 6));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('You are facing the Qibla'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Calibrate the compass'), findsNothing);
    });

    testWidgets('asks for calibration when the sensor is unsure', (tester) async {
      tallPhone(tester);
      final compass = StreamController<CompassEvent>();
      addTearDown(compass.close);
      await tester.pumpWidget(host(QiblaView(location: cairo, compassEvents: compass.stream)));
      compass.add(_event(10, accuracy: 45));
      await tester.pump();
      // Not straight away: the sensor often reports its accuracy late.
      expect(find.text('Calibrate the compass'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      compass.add(_event(10, accuracy: 45));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Calibrate the compass'), findsOneWidget);

      compass.add(_event(10, accuracy: 15));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Calibrate the compass'), findsNothing);
    });

    testWidgets('warns when the direction is from the default city', (tester) async {
      tallPhone(tester);
      SharedPreferences.setMockInitialValues({});
      await LocalStorageServices.init();
      await tester.pumpWidget(
        host(
          QiblaView(
            location: PrayerTimesService.currentLocation(),
            compassEvents: const Stream.empty(),
          ),
        ),
      );
      // The GPS lookup fails for real (no plugin in tests), off the fake clock.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Your location is not set'), findsOneWidget);
      expect(find.text('Set location'), findsOneWidget);
    });
  });
}
