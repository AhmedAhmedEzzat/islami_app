import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/prayer_notification_service.dart';
import '../../core/state/settings_cubit.dart';
import '../../core/utils/l10n_ext.dart';

/// Asks for what prayer notifications need and turns them on if allowed.
/// Returns whether they are on. Only call this from a user action: Android 13+
/// may silently refuse a permission prompt nobody asked for.
Future<bool> turnOnPrayerNotifications(BuildContext context) async {
  final cubit = context.read<SettingsCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  final result = await PrayerNotificationService.requestPermissions();
  switch (result) {
    case NotificationPermission.denied:
      messenger.showSnackBar(SnackBar(content: Text(l10n.notificationsDenied)));
      return false;
    case NotificationPermission.grantedInexact:
      await cubit.setPrayerNotifications(true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.notificationsInexact)));
      return true;
    case NotificationPermission.granted:
      await cubit.setPrayerNotifications(true);
      return true;
  }
}
