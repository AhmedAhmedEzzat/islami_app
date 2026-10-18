import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sakina/core/services/islamic_calendar.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/core/state/settings_cubit.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/more/date_converter_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
    await initializeDateFormatting();
    HijriCalendar.setLocal('en');
  });

  test('every Hijri year offered converts there and back', () {
    for (var y = DateConverterView.firstHijriYear; y <= DateConverterView.lastHijriYear; y++) {
      for (final m in [1, 9, 12]) {
        final g = IslamicCalendar.toGregorian(y, m, 1);
        final back = IslamicCalendar.of(g);
        expect((back.hYear, back.hMonth, back.hDay), (y, m, 1), reason: '$y/$m');
      }
    }
  });

  test('every date the picker offers lands in a year the dropdown lists', () {
    for (final d in [DateTime(1938), DateTime(2076, 12, 31)]) {
      for (final offset in [-2, 0, 2]) {
        final y = IslamicCalendar.of(d, offset: offset).hYear;
        expect(y, inInclusiveRange(DateConverterView.firstHijriYear, DateConverterView.lastHijriYear));
      }
    }
  });

  testWidgets('switching direction carries the same day across', (tester) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => SettingsCubit()..load(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DateConverterView(),
        ),
      ),
    );
    final today = IslamicCalendar.of(DateTime.now());
    expect(find.textContaining('${today.hDay} ${today.longMonthName} ${today.hYear} AH'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.text('Hijri → Gregorian'));
    await tester.pumpAndSettle();
    // The same day, now as the Gregorian result.
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('${today.hYear}'), findsOneWidget);
  });
}
