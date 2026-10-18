import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workmanager/workmanager.dart';

import '../constants/muezzins.dart';

import '../state/settings_cubit.dart';
import '../state/settings_state.dart';
import 'khatma.dart';
import 'prayer_notification_service.dart';
import 'prayer_widget.dart';
import 'shared_prefs_helper.dart';

/// Keeps the notification schedule topped up.
///
/// [PrayerNotificationService] schedules [PrayerNotificationService.daysAhead]
/// days at a time, so without this the adhan would stop two weeks after the
/// app was last opened. A background task every 12 hours rebuilds the
/// schedule from the saved settings, the same way opening the app does.
abstract final class NotificationRefresh {
  static const String _taskName = 'refresh-prayer-notifications';

  /// Rebuilds the schedule from [state]. The one place that turns settings
  /// into a [PrayerNotificationService.reschedule] call, so the app and the
  /// background task can never disagree about what to schedule.
  static Future<void> reschedule(SettingsState state, Locale locale) async {
    // The widget shows the times whether or not notifications are on.
    await PrayerWidget.update(config: state.prayerConfig, locale: locale);
    return PrayerNotificationService.reschedule(
      enabled: state.prayerNotifications,
      locale: locale,
      config: state.prayerConfig,
      prayers: state.notifiedPrayers,
      reminderMinutes: state.reminderMinutes,
      fridayKahf: state.fridayKahf,
      fasting: state.fastingAlerts,
      hijriOffset: state.hijriOffset,
      sound: state.prayerSound,
      muezzin: Muezzins.byId(state.muezzinId),
      adhkar: state.adhkarReminders,
      // Only while a khatma is under way.
      khatma: state.khatmaReminders && Khatma.isActive,
    );
  }

  /// Registers the background task. Call once from `main()`; registering again
  /// keeps the existing task rather than restarting its clock.
  ///
  /// Android only: iOS needs a BGTaskScheduler identifier in Info.plist and
  /// AppDelegate set-up before a periodic task can be registered.
  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Workmanager().initialize(notificationRefreshDispatcher);
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        // Android runs it at most this often, and later when the phone is
        // dozing, which is fine with two weeks of slack.
        frequency: const Duration(hours: 12),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('Background refresh not registered: $e');
    }
  }
}

/// Runs in a background isolate, with none of the app's state, so it loads
/// everything it needs from storage.
@pragma('vm:entry-point')
void notificationRefreshDispatcher() {
  Workmanager().executeTask((task, _) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await LocalStorageServices.init();
      await initializeDateFormatting();
      final state = (SettingsCubit()..load()).state;
      await NotificationRefresh.reschedule(
        state,
        state.locale ?? PlatformDispatcher.instance.locale,
      );
      return true;
    } catch (e) {
      debugPrint('Background refresh failed: $e');
      // Asks WorkManager to retry with backoff.
      return false;
    }
  });
}
