import 'package:flutter/widgets.dart';

import '../services/prayer_times_service.dart';
import 'l10n_ext.dart';

/// Localized name of a prayer.
String prayerLabel(BuildContext context, PrayerName prayer) {
  final l10n = context.l10n;
  return switch (prayer) {
    PrayerName.fajr => l10n.prayerFajr,
    PrayerName.sunrise => l10n.prayerSunrise,
    PrayerName.dhuhr => l10n.prayerDhuhr,
    PrayerName.asr => l10n.prayerAsr,
    PrayerName.maghrib => l10n.prayerMaghrib,
    PrayerName.isha => l10n.prayerIsha,
  };
}

/// Localized name of a calculation method key (see PrayerConfig.methods).
String methodLabel(BuildContext context, String key) {
  final l10n = context.l10n;
  return switch (key) {
    'muslimWorldLeague' => l10n.methodMwl,
    'ummAlQura' => l10n.methodUmmAlQura,
    'karachi' => l10n.methodKarachi,
    'northAmerica' => l10n.methodNorthAmerica,
    'dubai' => l10n.methodDubai,
    'kuwait' => l10n.methodKuwait,
    'qatar' => l10n.methodQatar,
    'singapore' => l10n.methodSingapore,
    'turkey' => l10n.methodTurkey,
    'tehran' => l10n.methodTehran,
    'moonsightingCommittee' => l10n.methodMoonsighting,
    _ => l10n.methodEgyptian,
  };
}
