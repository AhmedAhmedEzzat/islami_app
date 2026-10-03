import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/prayer_config.dart';
import '../services/prayer_times_service.dart';

/// User preferences that affect the whole app.
@immutable
class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.quranFontScale = 1.0,
    this.reciterId = 'alafasy',
    this.calculationMethod = 'egyptian',
    this.locale,
    this.prayerNotifications = false,
    this.madhab = 'shafi',
    this.highLatitude = 'middle',
    this.adjustments = const {},
    this.reminderMinutes = 0,
    this.notifiedPrayers = defaultNotifiedPrayers,
    this.fridayKahf = true,
    this.hijriOffset = 0,
  });

  final ThemeMode themeMode;

  /// Multiplier applied to the Quran verse text size. 0.8x - 2.0x.
  final double quranFontScale;

  final String reciterId;
  final String calculationMethod;

  /// Null means follow the phone's language.
  final Locale? locale;

  /// Off until the user turns it on, because it needs a runtime permission.
  final bool prayerNotifications;

  /// 'shafi' or 'hanafi' — only Asr differs.
  final String madhab;

  /// 'middle', 'seventh' or 'twilight'.
  final String highLatitude;

  /// Minutes added to each prayer.
  final Map<PrayerName, int> adjustments;

  /// A heads-up this many minutes before each prayer. 0 = off.
  final int reminderMinutes;

  /// Which prayers get a notification.
  final Set<PrayerName> notifiedPrayers;

  /// A Friday-morning reminder to read Surat Al-Kahf.
  final bool fridayKahf;

  /// Days added to every Hijri date, -2..2, to match local moon sighting.
  final int hijriOffset;

  static const double minFontScale = 0.8;
  static const double maxFontScale = 2.0;

  static const Set<PrayerName> defaultNotifiedPrayers = {
    PrayerName.fajr,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  };

  static const List<int> reminderChoices = [0, 5, 10, 15, 20, 30];

  PrayerConfig get prayerConfig => PrayerConfig(
    method: calculationMethod,
    madhab: madhab,
    highLatitude: highLatitude,
    adjustments: adjustments,
  );

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? quranFontScale,
    String? reciterId,
    String? calculationMethod,
    Locale? locale,
    bool? prayerNotifications,
    String? madhab,
    String? highLatitude,
    Map<PrayerName, int>? adjustments,
    int? reminderMinutes,
    Set<PrayerName>? notifiedPrayers,
    bool? fridayKahf,
    int? hijriOffset,
    // Distinguishes "leave unchanged" from "back to the system language".
    bool clearLocale = false,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      quranFontScale: quranFontScale ?? this.quranFontScale,
      reciterId: reciterId ?? this.reciterId,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      locale: clearLocale ? null : (locale ?? this.locale),
      prayerNotifications: prayerNotifications ?? this.prayerNotifications,
      madhab: madhab ?? this.madhab,
      highLatitude: highLatitude ?? this.highLatitude,
      adjustments: adjustments ?? this.adjustments,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      notifiedPrayers: notifiedPrayers ?? this.notifiedPrayers,
      fridayKahf: fridayKahf ?? this.fridayKahf,
      hijriOffset: hijriOffset ?? this.hijriOffset,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SettingsState &&
        other.themeMode == themeMode &&
        other.quranFontScale == quranFontScale &&
        other.reciterId == reciterId &&
        other.calculationMethod == calculationMethod &&
        other.locale == locale &&
        other.prayerNotifications == prayerNotifications &&
        other.madhab == madhab &&
        other.highLatitude == highLatitude &&
        mapEquals(other.adjustments, adjustments) &&
        other.reminderMinutes == reminderMinutes &&
        setEquals(other.notifiedPrayers, notifiedPrayers) &&
        other.fridayKahf == fridayKahf &&
        other.hijriOffset == hijriOffset;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    quranFontScale,
    reciterId,
    calculationMethod,
    locale,
    prayerNotifications,
    madhab,
    highLatitude,
    PrayerConfig.encodeAdjustments(adjustments),
    reminderMinutes,
    Object.hashAllUnordered(notifiedPrayers),
    fridayKahf,
    hijriOffset,
  );
}
