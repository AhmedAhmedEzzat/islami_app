import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../constants/prefs_keys.dart';
import 'prayer_config.dart';
import 'prayer_notification_service.dart';
import 'prayer_times_service.dart';
import 'shared_prefs_helper.dart';

/// Feeds the Android home screen widget (PrayerWidget.kt).
///
/// The widget runs no Dart, so the app hands it the next [days] days of
/// prayer times, already named and formatted in the app's language. The
/// widget picks the next one itself and wakes at each prayer time to move on.
/// The app refreshes the list whenever it reschedules notifications, which
/// includes its twice-daily background task, so it never runs out.
abstract final class PrayerWidget {
  static const int days = 14;
  static const MethodChannel _channel = MethodChannel('sakina/widget');

  /// The JSON the widget reads. Pure, for tests.
  @visibleForTesting
  static Map<String, Object> data({
    required PrayerLocation location,
    required PrayerConfig config,
    required DateTime now,
    required Locale locale,
  }) {
    final l10n = PrayerNotificationService.l10nFor(locale);
    final format = DateFormat.jm(l10n.localeName);
    final today = DateTime(now.year, now.month, now.day);
    return {
      'rtl': l10n.localeName == 'ar',
      'place': location.isFallback ? l10n.defaultLocation : (location.name ?? ''),
      'next': l10n.widgetNextPrayer,
      'stale': l10n.widgetStale,
      'prayers': [
        for (var d = 0; d < days; d++)
          for (final e in PrayerTimesService.computeFor(
            coordinates: location.coordinates,
            date: DateTime(today.year, today.month, today.day + d),
            config: config,
          ).prayers)
            if (e.prayer != PrayerName.sunrise)
              {
                't': e.time.millisecondsSinceEpoch,
                'n': PrayerNotificationService.labelFor(l10n, e.prayer),
                's': format.format(e.time),
                'd': DateFormat('yyyy-MM-dd').format(e.time),
              },
      ],
    };
  }

  /// Saves the times for the widget and asks it to redraw.
  static Future<void> update({required PrayerConfig config, required Locale locale}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final json = data(
      location: PrayerTimesService.currentLocation(),
      config: config,
      now: DateTime.now(),
      locale: locale,
    );
    await LocalStorageServices.setString(PrefsKeys.widgetPrayers, jsonEncode(json));
    try {
      await _channel.invokeMethod<void>('update');
    } on MissingPluginException {
      // The background task has no activity to talk to. The widget picks the
      // new times up at its next prayer-time or half-hourly refresh.
    } on PlatformException catch (e) {
      debugPrint('Widget not refreshed: $e');
    }
  }
}
