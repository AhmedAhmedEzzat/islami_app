import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/prefs_keys.dart';
import '../../core/services/backup.dart';
import '../../core/services/daily_deeds.dart';
import '../../core/services/hadeth_favourites.dart';
import '../../core/services/hifz.dart';
import '../../core/services/khatma.dart';
import '../../core/services/names_learning.dart';
import '../../core/services/notification_refresh.dart';
import '../../core/services/reading_stats.dart';
import '../../core/services/recent_suras.dart';
import '../../core/state/bookmarks_cubit.dart';
import '../../core/state/settings_cubit.dart';
import '../../core/state/verse_notes_cubit.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/app_restart.dart';
import 'prayer_notifications_prompt.dart';

/// Saving the reader's data to a file and bringing it back, for a new phone.
class BackupTiles extends StatelessWidget {
  const BackupTiles({super.key});

  static const MethodChannel _files = MethodChannel('sakina/files');

  /// Backups need the native file picker to come back in.
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _save(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = DateTime.now();
      final name = 'sakina-backup-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
      final file = File('${(await getTemporaryDirectory()).path}/$name');
      await file.writeAsString(Backup.encode(now: now));
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/json')], subject: l10n.backupShareSubject),
      );
    } catch (e) {
      debugPrint('Backup not saved: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<SettingsCubit>();
    if (AppRestart.busy) return;
    final bookmarks = context.read<BookmarksCubit>();
    final notes = context.read<VerseNotesCubit>();
    final String? text;
    try {
      text = await _files.invokeMethod<String>('openText');
    } on PlatformException catch (e) {
      debugPrint('Backup not read: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupNotValid)));
      return;
    }
    if (text == null || !context.mounted) return;
    final file = Backup.decode(text);
    if (file == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupNotValid)));
      return;
    }
    final created = file.created;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.restore),
        title: Text(l10n.backupRestoreTitle),
        content: Text(
          created == null
              ? l10n.backupRestoreConfirm
              : l10n.backupRestoreConfirmDated(MaterialLocalizations.of(context).formatMediumDate(created)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.backupRestore)),
        ],
      ),
    );
    if (ok != true) return;
    // Notifications need this phone's permission, so they are turned on by
    // asking for it once the backup is in, not by copying the switch.
    final notifications = file.entries[PrefsKeys.prayerNotifications] == true;
    final entries = {...file.entries, if (notifications) PrefsKeys.prayerNotifications: false};
    final done = await AppRestart.around(() async {
      await Backup.restore(BackupFile(file.created, entries));
      // App-wide state that read storage at start-up reads it again; the
      // screens themselves are built afresh.
      settings.load();
      bookmarks.load();
      notes.load();
      Khatma.reload();
      HadethFavourites.reload();
      RecentSuras.reload();
      Hifz.changes.value++;
      DailyDeeds.changes.value++;
      ReadingStats.changes.value++;
      NamesLearning.changes.value++;
    });
    if (!done) return;
    final context2 = AppRestart.navigatorKey.currentContext;
    if (context2 != null && context2.mounted) {
      ScaffoldMessenger.of(context2).showSnackBar(SnackBar(content: Text(l10n.backupRestored)));
      // Asking turns them on, which reschedules everything by itself.
      if (notifications) {
        unawaited(turnOnPrayerNotifications(context2));
        return;
      }
    }
    // The schedule and the widget follow the restored settings and location
    // even when no setting the listener watches has changed.
    final state = settings.state;
    unawaited(NotificationRefresh.reschedule(state, state.locale ?? PlatformDispatcher.instance.locale));
  }

  @override
  Widget build(BuildContext context) {
    if (!supported) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(l10n.backupSave),
          subtitle: Text(l10n.backupSaveSubtitle),
          onTap: () => _save(context),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: Text(l10n.backupRestore),
          subtitle: Text(l10n.backupRestoreSubtitle),
          onTap: () => _restore(context),
        ),
      ],
    );
  }
}
