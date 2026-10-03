import 'dart:ui';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/gen/app_localizations.dart';
import 'prayer_config.dart';
import 'prayer_times_service.dart';

enum AlertKind { prayer, reminder, kahf }

/// One notification the schedule will post.
@immutable
class ScheduledAlert {
  const ScheduledAlert(this.id, this.kind, this.prayer, this.time);

  final int id;
  final AlertKind kind;

  /// Null for the Al-Kahf reminder.
  final PrayerName? prayer;
  final DateTime time;
}

/// What happened when notifications were turned on.
enum NotificationPermission { granted, grantedInexact, denied }

/// Schedules a notification at each of the five daily prayers.
///
/// Prayer times move by a minute or so every day, so a single repeating
/// notification would drift. Instead each prayer for the next [daysAhead]
/// days is scheduled individually, and the whole set is rebuilt every time
/// the app opens or a setting that affects the times changes.
abstract final class PrayerNotificationService {
  static const int daysAhead = 14;
  static const String _channelId = 'prayer_times';

  /// Notification ids are `_idBase + day * 10 + prayer`, so the prayer set can
  /// be cancelled without touching any other notification the app posts.
  static const int _idBase = 1000;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialised = false;

  /// Sunrise is not a prayer, so it gets no notification.
  static const List<PrayerName> notifiedPrayers = [
    PrayerName.fajr,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  ];

  static Future<void> init() async {
    if (_initialised || kIsWeb) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      // Leaves tz.local as UTC. Times are still converted from the device's
      // local DateTime, so they stay correct; only DST edge cases suffer.
      debugPrint('Could not resolve local time zone: $e');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        // White mark on transparent: status-bar icons are drawn as a mask.
        android: AndroidInitializationSettings('@drawable/ic_launcher_monochrome'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialised = true;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Asks for what the notifications need. Only call this from a user action:
  /// Android 13+ may silently refuse a permission prompt nobody asked for.
  static Future<NotificationPermission> requestPermissions() async {
    await init();

    final android = _android;
    if (android != null) {
      final allowed = await android.requestNotificationsPermission() ?? false;
      if (!allowed) return NotificationPermission.denied;

      // Android 14 does not grant exact alarms by default; this opens the
      // system screen where the user can allow them.
      if (!(await android.canScheduleExactNotifications() ?? false)) {
        await android.requestExactAlarmsPermission();
      }
      return (await android.canScheduleExactNotifications() ?? false)
          ? NotificationPermission.granted
          : NotificationPermission.grantedInexact;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin
    >();
    final allowed =
        await ios?.requestPermissions(alert: true, sound: true) ?? false;
    return allowed ? NotificationPermission.granted : NotificationPermission.denied;
  }

  /// Ids are partitioned by kind so the whole set can be cancelled without
  /// touching any other notification the app posts:
  ///   prayers   1000 + day * 10 + prayer
  ///   reminders 2000 + day * 10 + prayer
  ///   Al-Kahf   3000 + day
  static const int _reminderBase = 2000;
  static const int _kahfBase = 3000;

  /// Cancels every notification this service scheduled.
  static Future<void> cancelAll() async {
    await init();
    for (var day = 0; day < daysAhead; day++) {
      for (var p = 0; p < notifiedPrayers.length; p++) {
        await _plugin.cancel(id: _idBase + day * 10 + p);
        await _plugin.cancel(id: _reminderBase + day * 10 + p);
      }
      await _plugin.cancel(id: _kahfBase + day);
    }
  }

  /// Everything to schedule from [now] for [daysAhead] days, in time order.
  ///
  /// Pure, so the scheduling rules can be tested without the plugin.
  static List<ScheduledAlert> plan({
    required Coordinates coordinates,
    required DateTime now,
    PrayerConfig config = const PrayerConfig(),
    Set<PrayerName> prayers = const {
      PrayerName.fajr,
      PrayerName.dhuhr,
      PrayerName.asr,
      PrayerName.maghrib,
      PrayerName.isha,
    },
    int reminderMinutes = 0,
    bool fridayKahf = false,
  }) {
    final result = <ScheduledAlert>[];
    final today = DateTime(now.year, now.month, now.day);

    for (var day = 0; day < daysAhead; day++) {
      final date = today.add(Duration(days: day));
      final times = PrayerTimesService.computeFor(
        coordinates: coordinates,
        date: date,
        config: config,
      );
      for (var p = 0; p < notifiedPrayers.length; p++) {
        final prayer = notifiedPrayers[p];
        if (!prayers.contains(prayer)) continue;
        final time = times.entry(prayer).time;

        // Nothing in the past: Android fires those immediately.
        if (time.isAfter(now)) {
          result.add(ScheduledAlert(_idBase + day * 10 + p, AlertKind.prayer, prayer, time));
        }
        if (reminderMinutes > 0) {
          final early = time.subtract(Duration(minutes: reminderMinutes));
          if (early.isAfter(now)) {
            result.add(
              ScheduledAlert(_reminderBase + day * 10 + p, AlertKind.reminder, prayer, early),
            );
          }
        }
      }

      if (fridayKahf && date.weekday == DateTime.friday) {
        final morning = DateTime(date.year, date.month, date.day, 10);
        if (morning.isAfter(now)) {
          result.add(ScheduledAlert(_kahfBase + day, AlertKind.kahf, null, morning));
        }
      }
    }

    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  /// Rebuilds the full schedule. Safe to call often.
  static Future<void> reschedule({
    required bool enabled,
    required Locale locale,
    PrayerConfig config = const PrayerConfig(),
    Set<PrayerName>? prayers,
    int reminderMinutes = 0,
    bool fridayKahf = false,
  }) async {
    if (kIsWeb) return;
    await init();
    await cancelAll();
    if (!enabled) return;

    final coordinates = PrayerTimesService.currentLocation().coordinates;
    final l10n = lookupAppLocalizations(
      AppLocalizations.supportedLocales.any(
            (l) => l.languageCode == locale.languageCode,
          )
          ? Locale(locale.languageCode)
          : const Locale('en'),
    );

    final exact = await _android?.canScheduleExactNotifications() ?? true;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.prayerChannelName,
        channelDescription: l10n.prayerChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(presentSound: true),
    );

    final alerts = plan(
      coordinates: coordinates,
      now: DateTime.now(),
      config: config,
      prayers: prayers ?? notifiedPrayers.toSet(),
      reminderMinutes: reminderMinutes,
      fridayKahf: fridayKahf,
    );

    for (final alert in alerts) {
      final name = alert.prayer == null ? '' : _label(l10n, alert.prayer!);
      final (title, body) = switch (alert.kind) {
        AlertKind.prayer => (
          l10n.prayerNotificationTitle(name),
          l10n.prayerNotificationBody(name),
        ),
        AlertKind.reminder => (
          l10n.reminderTitle(name),
          l10n.reminderBody(reminderMinutes, name),
        ),
        AlertKind.kahf => (l10n.kahfTitle, l10n.kahfBody),
      };
      await _plugin.zonedSchedule(
        id: alert.id,
        scheduledDate: tz.TZDateTime.from(alert.time, tz.local),
        notificationDetails: details,
        // Exact when the user has allowed it; otherwise Android batches the
        // alarm and it can arrive several minutes late.
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    }
  }

  static String _label(AppLocalizations l10n, PrayerName prayer) {
    return switch (prayer) {
      PrayerName.fajr => l10n.prayerFajr,
      PrayerName.sunrise => l10n.prayerSunrise,
      PrayerName.dhuhr => l10n.prayerDhuhr,
      PrayerName.asr => l10n.prayerAsr,
      PrayerName.maghrib => l10n.prayerMaghrib,
      PrayerName.isha => l10n.prayerIsha,
    };
  }
}
