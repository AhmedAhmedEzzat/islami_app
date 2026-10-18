import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/reciters.dart';
import '../../../../core/services/recitation_downloads.dart';
import '../../../../core/state/quran_player_cubit.dart';
import '../../../../core/state/quran_player_state.dart';
import '../../../../core/state/settings_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/l10n_ext.dart';
import '../../../../models/sura_data_model.dart';
import '../../widgets/sleep_timer_sheet.dart';

/// Recitation controls pinned under the mushaf.
class QuranPlayerBar extends StatelessWidget {
  const QuranPlayerBar({super.key, required this.sura});

  final SuraDataModel sura;

  int get _total => int.tryParse(sura.suraVersesNumber) ?? 0;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return BlocConsumer<QuranPlayerCubit, QuranPlayerState>(
      listenWhen: (a, b) => a.errorKey != b.errorKey && b.errorKey != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.recitationOffline)),
        );
        context.read<QuranPlayerCubit>().clearError();
      },
      builder: (context, state) {
        final cubit = context.read<QuranPlayerCubit>();
        final isThis = state.isLoaded(sura.suraID);
        final reciterId = context.read<SettingsCubit>().state.reciterId;
        final reciter = Reciters.byId(reciterId);

        final String status;
        if (!isThis) {
          status = context.isArabic ? reciter.nameAr : reciter.nameEn;
        } else if (state.ayah == 0) {
          status = context.l10n.basmalaPlaying;
        } else {
          status = context.l10n.verseOfTotal(state.ayah ?? 1, _total);
        }

        return Material(
          color: scheme.surfaceContainerHigh,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isThis)
                LinearProgressIndicator(
                  value: state.isBuffering ? null : state.suraProgress,
                  minHeight: 2,
                  backgroundColor: scheme.surfaceContainerHigh,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: _repeatLabel(context, state.repeat),
                      onPressed: cubit.cycleRepeat,
                      color: state.repeat == RecitationRepeat.off
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                      icon: Icon(switch (state.repeat) {
                        RecitationRepeat.off => Icons.repeat,
                        RecitationRepeat.verse => Icons.repeat_one,
                        RecitationRepeat.sura => Icons.repeat_on,
                      }),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SleepTimerBadge(),
                        ],
                      ),
                    ),
                    // Previous/next follow reading direction: in an Arabic
                    // mushaf "next" points left.
                    IconButton(
                      tooltip: context.l10n.previousVerse,
                      onPressed: isThis ? cubit.previousVerse : null,
                      icon: const Icon(Icons.skip_previous),
                    ),
                    IconButton.filled(
                      tooltip: isThis && state.isPlaying
                          ? context.l10n.pauseRecitation
                          : context.l10n.playRecitation,
                      onPressed: () => cubit.toggle(
                        suraId: sura.suraID,
                        totalAyahs: _total,
                        reciterId: reciterId,
                      ),
                      icon: isThis && state.isBuffering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Icon(
                              isThis && state.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                    ),
                    IconButton(
                      tooltip: context.l10n.nextVerse,
                      onPressed: isThis ? cubit.nextVerse : null,
                      icon: const Icon(Icons.skip_next),
                    ),
                    _MoreMenu(reciter: reciter, sura: int.parse(sura.suraID)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _repeatLabel(BuildContext context, RecitationRepeat mode) {
    return switch (mode) {
      RecitationRepeat.off => context.l10n.repeatOff,
      RecitationRepeat.verse => context.l10n.repeatVerse,
      RecitationRepeat.sura => context.l10n.repeatSura,
    };
  }
}

/// Sleep timer, continuous play and this sura's download, which do not need
/// a button each on the bar.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.reciter, required this.sura});

  final Reciter reciter;
  final int sura;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = context.read<SettingsCubit>();
    return ValueListenableBuilder<int>(
      valueListenable: RecitationDownloads.changes,
      builder: (context, _, _) {
        final downloaded = RecitationDownloads.isDownloaded(reciter.id, sura);
        final job = RecitationDownloads.jobFor(reciter.id, sura);
        final busy = job != null && job.status != DownloadStatus.failed;
        return PopupMenuButton<void>(
          tooltip: l10n.moreOptions,
          // A ring on the menu button while this sura downloads.
          icon: busy
              ? SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(value: job.progress, strokeWidth: 2.5),
                )
              : const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: () => showSleepTimerSheet(context, offerEndOfSura: true),
              child: ListTile(leading: const Icon(Icons.bedtime_outlined), title: Text(l10n.sleepTimer)),
            ),
            CheckedPopupMenuItem(
              checked: settings.state.continuousRecitation,
              onTap: () => settings.setContinuousRecitation(!settings.state.continuousRecitation),
              child: Text(l10n.continuousRecitation),
            ),
            if (RecitationDownloads.supported)
              PopupMenuItem(
                onTap: () {
                  if (downloaded) {
                    RecitationDownloads.delete(reciter, sura);
                  } else if (busy) {
                    RecitationDownloads.cancel(reciter.id);
                  } else {
                    RecitationDownloads.download(reciter, sura);
                  }
                },
                child: ListTile(
                  leading: Icon(downloaded
                      ? Icons.delete_outline
                      : busy
                      ? Icons.stop_rounded
                      : Icons.download_outlined),
                  title: Text(downloaded
                      ? l10n.removeDownload
                      : busy
                      ? l10n.stopDownloads
                      : l10n.downloadForOffline),
                ),
              ),
          ],
        );
      },
    );
  }
}
