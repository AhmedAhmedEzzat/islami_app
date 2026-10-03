import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/prefs_keys.dart';
import '../services/prayer_config.dart';
import '../services/prayer_times_service.dart';
import '../services/shared_prefs_helper.dart';
import 'settings_state.dart';

/// Holds the user's preferences and writes each change straight through to
/// storage, so nothing is lost if the app is killed.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  /// Called from `main()` before `runApp` so the first frame already has the
  /// right theme and there is no flash of the wrong brightness.
  void load() {
    emit(
      SettingsState(
        themeMode: _decodeThemeMode(
          LocalStorageServices.getString(PrefsKeys.themeMode),
        ),
        quranFontScale:
            LocalStorageServices.getDouble(PrefsKeys.quranFontScale) ?? 1.0,
        reciterId:
            LocalStorageServices.getString(PrefsKeys.reciterId) ?? 'alafasy',
        calculationMethod:
            LocalStorageServices.getString(PrefsKeys.calculationMethod) ??
            'egyptian',
        locale: _decodeLocale(
          LocalStorageServices.getString(PrefsKeys.locale),
        ),
        prayerNotifications:
            LocalStorageServices.getBool(PrefsKeys.prayerNotifications) ??
            false,
        madhab: LocalStorageServices.getString(PrefsKeys.madhab) ?? 'shafi',
        highLatitude:
            LocalStorageServices.getString(PrefsKeys.highLatitude) ?? 'middle',
        adjustments: PrayerConfig.decodeAdjustments(
          LocalStorageServices.getString(PrefsKeys.prayerAdjustments),
        ),
        reminderMinutes:
            LocalStorageServices.getInt(PrefsKeys.reminderMinutes) ?? 0,
        notifiedPrayers: _decodePrayers(
          LocalStorageServices.getString(PrefsKeys.notifiedPrayers),
        ),
        fridayKahf: LocalStorageServices.getBool(PrefsKeys.fridayKahf) ?? true,
        hijriOffset: LocalStorageServices.getInt(PrefsKeys.hijriOffset) ?? 0,
      ),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(state.copyWith(themeMode: mode));
    await LocalStorageServices.setString(PrefsKeys.themeMode, mode.name);
  }

  Future<void> setQuranFontScale(double scale) async {
    final clamped = scale.clamp(
      SettingsState.minFontScale,
      SettingsState.maxFontScale,
    );
    emit(state.copyWith(quranFontScale: clamped));
    await LocalStorageServices.setDouble(PrefsKeys.quranFontScale, clamped);
  }

  Future<void> setReciter(String id) async {
    emit(state.copyWith(reciterId: id));
    await LocalStorageServices.setString(PrefsKeys.reciterId, id);
  }

  Future<void> setCalculationMethod(String method) async {
    emit(state.copyWith(calculationMethod: method));
    await LocalStorageServices.setString(PrefsKeys.calculationMethod, method);
  }

  Future<void> setPrayerNotifications(bool enabled) async {
    emit(state.copyWith(prayerNotifications: enabled));
    await LocalStorageServices.setBool(PrefsKeys.prayerNotifications, enabled);
  }

  /// Empty string or null means follow the phone.
  Future<void> setLocale(Locale? locale) async {
    emit(state.copyWith(locale: locale, clearLocale: locale == null));
    await LocalStorageServices.setString(
      PrefsKeys.locale,
      locale?.languageCode ?? '',
    );
  }

  Future<void> setMadhab(String madhab) async {
    emit(state.copyWith(madhab: madhab));
    await LocalStorageServices.setString(PrefsKeys.madhab, madhab);
  }

  Future<void> setHighLatitude(String rule) async {
    emit(state.copyWith(highLatitude: rule));
    await LocalStorageServices.setString(PrefsKeys.highLatitude, rule);
  }

  /// Minutes added to [prayer], clamped to ±30 — a sanity bound, since a
  /// larger offset almost certainly means the wrong calculation method.
  Future<void> setAdjustment(PrayerName prayer, int minutes) async {
    final next = Map<PrayerName, int>.from(state.adjustments)
      ..[prayer] = minutes.clamp(-30, 30);
    emit(state.copyWith(adjustments: next));
    await LocalStorageServices.setString(
      PrefsKeys.prayerAdjustments,
      PrayerConfig.encodeAdjustments(next),
    );
  }

  Future<void> setReminderMinutes(int minutes) async {
    emit(state.copyWith(reminderMinutes: minutes));
    await LocalStorageServices.setInt(PrefsKeys.reminderMinutes, minutes);
  }

  Future<void> togglePrayerNotification(PrayerName prayer) async {
    final next = Set<PrayerName>.from(state.notifiedPrayers);
    next.contains(prayer) ? next.remove(prayer) : next.add(prayer);
    emit(state.copyWith(notifiedPrayers: next));
    await LocalStorageServices.setString(
      PrefsKeys.notifiedPrayers,
      next.map((p) => p.name).join(','),
    );
  }

  Future<void> setFridayKahf(bool enabled) async {
    emit(state.copyWith(fridayKahf: enabled));
    await LocalStorageServices.setBool(PrefsKeys.fridayKahf, enabled);
  }

  Future<void> setHijriOffset(int days) async {
    final clamped = days.clamp(-2, 2);
    emit(state.copyWith(hijriOffset: clamped));
    await LocalStorageServices.setInt(PrefsKeys.hijriOffset, clamped);
  }

  /// Null (never set) means every prayer; an empty string means none.
  static Set<PrayerName> _decodePrayers(String? stored) {
    if (stored == null) return SettingsState.defaultNotifiedPrayers;
    return {
      for (final name in stored.split(','))
        ...PrayerName.values.where((p) => p.name == name),
    };
  }

  static Locale? _decodeLocale(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    return Locale(stored);
  }

  static ThemeMode _decodeThemeMode(String? stored) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }
}
