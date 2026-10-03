import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/core/state/settings_cubit.dart';
import 'package:sakina/core/state/settings_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
  });

  test('defaults to following the system theme at 1.0 scale', () {
    final cubit = SettingsCubit()..load();
    expect(cubit.state.themeMode, ThemeMode.system);
    expect(cubit.state.quranFontScale, 1.0);
    expect(cubit.state.reciterId, 'alafasy');
  });

  test('a saved theme mode survives a reload', () async {
    final first = SettingsCubit()..load();
    await first.setThemeMode(ThemeMode.dark);

    final second = SettingsCubit()..load();
    expect(second.state.themeMode, ThemeMode.dark);
  });

  test('font scale is clamped to the supported range', () async {
    final cubit = SettingsCubit()..load();

    await cubit.setQuranFontScale(9);
    expect(cubit.state.quranFontScale, SettingsState.maxFontScale);

    await cubit.setQuranFontScale(0.1);
    expect(cubit.state.quranFontScale, SettingsState.minFontScale);
  });

  test('an unrecognised stored theme falls back to system', () async {
    SharedPreferences.setMockInitialValues({'settings.themeMode': 'nonsense'});
    await LocalStorageServices.init();

    final cubit = SettingsCubit()..load();
    expect(cubit.state.themeMode, ThemeMode.system);
  });

  test('language choice survives a reload', () async {
    final first = SettingsCubit()..load();
    expect(first.state.locale, isNull, reason: 'defaults to the phone');

    await first.setLocale(const Locale('ar'));

    final second = SettingsCubit()..load();
    expect(second.state.locale, const Locale('ar'));
  });

  test('switching back to system clears the stored language', () async {
    final first = SettingsCubit()..load();
    await first.setLocale(const Locale('ar'));
    await first.setLocale(null);

    final second = SettingsCubit()..load();
    expect(second.state.locale, isNull);
  });

  test('reciter and calculation method persist', () async {
    final first = SettingsCubit()..load();
    await first.setReciter('abdulbasit');
    await first.setCalculationMethod('ummAlQura');

    final second = SettingsCubit()..load();
    expect(second.state.reciterId, 'abdulbasit');
    expect(second.state.calculationMethod, 'ummAlQura');
  });
}
