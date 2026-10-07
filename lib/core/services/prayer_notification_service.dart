import 'dart:ui';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/gen/app_localizations.dart';
import 'islamic_calendar.dart';
import 'prayer_config.dart';
import 'prayer_times_service.dart';

enum AlertKind {
  prayer,
  reminder,
  kahf,

  /// The evening before a Monday or Thursday.
  mondayThursday,

  /// The evening before the 13th, the first of the White Days.
  whiteDays,

  /// The evening before the Day of Arafah.
  arafah,

  /// The evening before Ashura.
  ashura,

  /// Suhoor, half an hour before Imsak, on each day of Ramadan.
  suhoor,

  /// Iftar, at Maghrib, on each day of Ramadan.
  iftar,
}

/// The fasting reminders a user can turn on, each with its own switch.
enum FastingAlert { mondayThursday, whiteDays, ramadan, arafahAshura }

/// One notification the schedule will post.
@immutable
class ScheduledAlert {
  const ScheduledAlert(this.id, this.kind, this.prayer, this.time);

  final int id;
  final AlertKind kind;

  /// Null for everything but the prayer alerts and their reminders.
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
  ///   fasting   4000 + day * 10 + slot (0 the evening before, 1 suhoor, 2 iftar)
  static const int _reminderBase = 2000;
  static const int _kahfBase = 3000;
  static const int _fastingBase = 4000;

  /// When the evening-before reminders arrive, after Isha in most places.
  static const int eveningHour = 21;

  /// Imsak is ten minutes before Fajr, as on the Home screen's Ramadan card;
  /// suhoor is called half an hour before that.
  static const Duration imsakBeforeFajr = Duration(minutes: 10);
  static const Duration suhoorBeforeImsak = Duration(minutes: 30);

  /// Cancels every notification this service scheduled.
  static Future<void> cancelAll() async {
    await init();
    for (var day = 0; day < daysAhead; day++) {
      for (var p = 0; p < notifiedPrayers.length; p++) {
        await _plugin.cancel(id: _idBase + day * 10 + p);
        await _plugin.cancel(id: _reminderBase + day * 10 + p);
      }
      await _plugin.cancel(id: _kahfBase + day);
      for (var slot = 0; slot < 3; slot++) {
        await _plugin.cancel(id: _fastingBase + day * 10 + slot);
      }
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
    Set<FastingAlert> fasting = const {},
    int hijriOffset = 0,
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

      final eveKind = _fastTomorrow(date, fasting, hijriOffset);
      if (eveKind != null) {
        final evening = DateTime(date.year, date.month, date.day, eveningHour);
        if (evening.isAfter(now)) {
          result.add(ScheduledAlert(_fastingBase + day * 10, eveKind, null, evening));
        }
      }

      if (fasting.contains(FastingAlert.ramadan) &&
          IslamicCalendar.ramadanDay(date, offset: hijriOffset) != null) {
        final suhoor = times.entry(PrayerName.fajr).time.subtract(imsakBeforeFajr + suhoorBeforeImsak);
        final iftar = times.entry(PrayerName.maghrib).time;
        if (suhoor.isAfter(now)) {
          result.add(ScheduledAlert(_fastingBase + day * 10 + 1, AlertKind.suhoor, null, suhoor));
        }
        if (iftar.isAfter(now)) {
          result.add(ScheduledAlert(_fastingBase + day * 10 + 2, AlertKind.iftar, null, iftar));
        }
      }
    }

    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  /// What to remind about on the evening of [eve], for the fast the next day:
  /// at most one reminder an evening, the rarer occasion first.
  ///
  /// Nothing before a day on which fasting is forbidden (the two Eids and the
  /// days of Tashreeq, 11th-13th Dhul-Hijjah), so the 13th of Dhul-Hijjah is
  /// not called a White Day. Nothing for Mondays, Thursdays or White Days in
  /// Ramadan, which is fasted anyway.
  static AlertKind? _fastTomorrow(DateTime eve, Set<FastingAlert> fasting, int hijriOffset) {
    if (fasting.isEmpty) return null;
    final tomorrow = eve.add(const Duration(days: 1));
    final h = IslamicCalendar.of(tomorrow, offset: hijriOffset);
    final forbidden = (h.hMonth == 10 && h.hDay == 1) || (h.hMonth == 12 && h.hDay >= 10 && h.hDay <= 13);
    if (forbidden || h.hMonth == 9) return null;

    if (fasting.contains(FastingAlert.arafahAshura)) {
      if (h.hMonth == 12 && h.hDay == 9) return AlertKind.arafah;
      if (h.hMonth == 1 && h.hDay == 10) return AlertKind.ashura;
    }
    if (fasting.contains(FastingAlert.whiteDays) && h.hDay == 13) {
      return AlertKind.whiteDays;
    }
    if (fasting.contains(FastingAlert.mondayThursday) &&
        (tomorrow.weekday == DateTime.monday || tomorrow.weekday == DateTime.thursday)) {
      return AlertKind.mondayThursday;
    }
    return null;
  }

  /// Rebuilds the full schedule. Safe to call often.
  static Future<void> reschedule({
    required bool enabled,
    required Locale locale,
    PrayerConfig config = const PrayerConfig(),
    Set<PrayerName>? prayers,
    int reminderMinutes = 0,
    bool fridayKahf = false,
    Set<FastingAlert> fasting = const {},
    int hijriOffset = 0,
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
      fasting: fasting,
      hijriOffset: hijriOffset,
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
        AlertKind.mondayThursday => (
          l10n.fastMondayThursdayTitle,
          alert.time.add(const Duration(days: 1)).weekday == DateTime.monday
              ? l10n.fastMondayBody
              : l10n.fastThursdayBody,
        ),
        AlertKind.whiteDays => (l10n.fastWhiteDaysTitle, l10n.fastWhiteDaysBody),
        AlertKind.arafah => (l10n.fastArafahTitle, l10n.fastArafahBody),
        AlertKind.ashura => (l10n.fastAshuraTitle, l10n.fastAshuraBody),
        AlertKind.suhoor => (l10n.suhoorTitle, l10n.suhoorBody),
        AlertKind.iftar => (l10n.iftarNotificationTitle, l10n.iftarNotificationBody),
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
