import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/constants.dart';
import '../../core/constants/reciters.dart';
import '../../core/services/recitation_downloads.dart';
import '../../core/state/quran_player_cubit.dart';
import '../../core/state/quran_player_state.dart';
import '../../core/state/settings_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';

/// Listen to any sura with any reciter, and keep recitations on the phone:
/// pick a reciter, play a sura (it carries on in the now-playing bar), or
/// download single suras or the whole Quran, see the space used, and delete.
class ListenView extends StatefulWidget {
  const ListenView({super.key});

  @override
  State<ListenView> createState() => _ListenViewState();
}

class _ListenViewState extends State<ListenView> {
  late Reciter _reciter = Reciters.byId(context.read<SettingsCubit>().state.reciterId);

  String _name(Reciter r) => context.isArabic ? r.nameAr : r.nameEn;

  Future<void> _pickReciter() async {
    final picked = await showDialog<Reciter>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.reciterLabel),
        children: [
          for (final r in Reciters.all)
            ListTile(
              title: Text(_name(r)),
              subtitle: RecitationDownloads.downloaded(r.id).isEmpty
                  ? null
                  : Text(context.l10n.surasDownloaded(RecitationDownloads.downloaded(r.id).length)),
              trailing: r.id == _reciter.id ? Icon(Icons.check, color: context.colors.primary) : null,
              onTap: () => Navigator.pop(context, r),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _reciter = picked);
  }

  /// Plays [suraId] with the reciter picked here, or pauses it if it is
  /// the one playing. It carries on in the now-playing bar.
  void _play(String suraId, int ayahs) {
    final player = context.read<QuranPlayerCubit>();
    // A different reciter picked here starts the sura afresh with them.
    if (player.state.isLoaded(suraId) && player.reciterId == _reciter.id) {
      player.togglePlayPause();
    } else {
      player.playFrom(suraId: suraId, fromAyah: 1, totalAyahs: ayahs, reciterId: _reciter.id);
    }
  }

  Future<void> _downloadAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.download_for_offline_outlined),
        title: Text(context.l10n.downloadWholeQuran),
        content: Text(context.l10n.downloadWholeQuranWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.download)),
        ],
      ),
    );
    if (ok == true) RecitationDownloads.downloadAll(_reciter);
  }

  Future<void> _deleteAll() async {
    final ok = await confirmDelete(context, context.l10n.deleteAllDownloads(_name(_reciter)));
    if (ok) await RecitationDownloads.deleteAll(_reciter);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;

    // Says so when a sura cannot be played, as the sura page does.
    return BlocListener<QuranPlayerCubit, QuranPlayerState>(
      listenWhen: (a, b) => a.errorKey != b.errorKey && b.errorKey != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.recitationOffline)));
        context.read<QuranPlayerCubit>().clearError();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.listenTitle)),
        body: BlocBuilder<QuranPlayerCubit, QuranPlayerState>(
          // Which sura plays, and whether, is all the list shows of the player.
          buildWhen: (a, b) => a.suraId != b.suraId || a.isPlaying != b.isPlaying,
          builder: (context, player) => ValueListenableBuilder<int>(
            valueListenable: RecitationDownloads.changes,
            builder: (context, _, _) {
              final done = RecitationDownloads.downloaded(_reciter.id);
              final busy = RecitationDownloads.isBusy(_reciter.id);
              final total = Constants.suraDataLists.length;

              return ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                children: [
                  ListTile(
                    leading: const Icon(Icons.record_voice_over_outlined),
                    title: Text(l10n.reciterLabel),
                    subtitle: Text(_name(_reciter)),
                    trailing: const Icon(Icons.unfold_more),
                    onTap: _pickReciter,
                  ),
                  if (RecitationDownloads.supported)
                    Padding(
                      padding: AppSpacing.pageH,
                      child: Card(
                        color: scheme.surfaceContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.surasDownloadedOf(done.length, total), style: context.texts.titleMedium),
                              const SizedBox(height: AppSpacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                child: LinearProgressIndicator(value: done.length / total, minHeight: 8),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              FutureBuilder<int>(
                                // Keyed on the count so the size follows each finished sura.
                                key: ValueKey('${_reciter.id}-${done.length}'),
                                future: RecitationDownloads.bytesOnDisk(_reciter),
                                builder: (context, snap) => Text(
                                  l10n.storageUsed(formatBytes(snap.data ?? 0)),
                                  style: context.texts.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  if (busy)
                                    FilledButton.tonalIcon(
                                      onPressed: () => RecitationDownloads.cancel(_reciter.id),
                                      icon: const Icon(Icons.stop_rounded),
                                      label: Text(l10n.stopDownloads),
                                    )
                                  else if (done.length < total)
                                    FilledButton.icon(
                                      onPressed: _downloadAll,
                                      icon: const Icon(Icons.download_rounded),
                                      label: Text(l10n.downloadWholeQuran),
                                    ),
                                  if (done.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: _deleteAll,
                                      icon: const Icon(Icons.delete_outline),
                                      label: Text(l10n.deleteAll),
                                    ),
                                ],
                              ),
                              if (busy) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  l10n.keepAppOpenWhileDownloading,
                                  style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final sura in Constants.suraDataLists)
                    Builder(
                      builder: (context) {
                        final current = player.isLoaded(sura.suraID);
                        final playing = current && player.isPlaying;
                        final ayahs = int.parse(sura.suraVersesNumber);
                        return ListTile(
                          selected: current,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: current ? scheme.primary : scheme.secondaryContainer,
                            child: Text(
                              sura.suraID,
                              style: context.texts.labelMedium?.copyWith(color: current ? scheme.onPrimary : null),
                            ),
                          ),
                          title: Text(context.isArabic ? sura.suraNameAR : sura.suraNameEN),
                          subtitle: Text(l10n.ayahsCount(ayahs)),
                          onTap: () => _play(sura.suraID, ayahs),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SuraDownloadButton(reciter: _reciter, sura: int.parse(sura.suraID)),
                              IconButton(
                                tooltip: playing ? l10n.pauseRecitation : l10n.playRecitation,
                                icon: Icon(playing ? Icons.pause_circle : Icons.play_circle_outline),
                                color: scheme.primary,
                                onPressed: () => _play(sura.suraID, ayahs),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "12.3 MB".
String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

Future<bool> confirmDelete(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: context.colors.error, foregroundColor: context.colors.onError),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.delete),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Downloads one sura, shows its progress, and removes it once saved.
class SuraDownloadButton extends StatelessWidget {
  const SuraDownloadButton({super.key, required this.reciter, required this.sura});

  final Reciter reciter;
  final int sura;

  @override
  Widget build(BuildContext context) {
    if (!RecitationDownloads.supported) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: RecitationDownloads.changes,
      builder: (context, _, _) {
        final l10n = context.l10n;
        final scheme = context.colors;
        final job = RecitationDownloads.jobFor(reciter.id, sura);

        if (RecitationDownloads.isDownloaded(reciter.id, sura)) {
          return IconButton(
            tooltip: l10n.downloadedTapToRemove,
            icon: Icon(Icons.download_done_rounded, color: scheme.primary),
            onPressed: () async {
              final name = context.isArabic
                  ? Constants.suraDataLists[sura - 1].suraNameAR
                  : Constants.suraDataLists[sura - 1].suraNameEN;
              if (await confirmDelete(context, l10n.deleteSuraDownload(name))) {
                await RecitationDownloads.delete(reciter, sura);
              }
            },
          );
        }
        return switch (job?.status) {
          DownloadStatus.downloading || DownloadStatus.queued => IconButton(
            tooltip: l10n.stopDownloads,
            onPressed: () => RecitationDownloads.cancel(reciter.id),
            icon: SizedBox.square(
              dimension: 22,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: job!.status == DownloadStatus.queued ? null : job.progress,
                    strokeWidth: 2.5,
                  ),
                  const Icon(Icons.stop_rounded, size: 12),
                ],
              ),
            ),
          ),
          DownloadStatus.failed => IconButton(
            tooltip: l10n.downloadFailedRetry,
            icon: Icon(Icons.refresh_rounded, color: scheme.error),
            onPressed: () => RecitationDownloads.download(reciter, sura),
          ),
          null => IconButton(
            tooltip: l10n.downloadForOffline,
            icon: const Icon(Icons.download_outlined),
            onPressed: () => RecitationDownloads.download(reciter, sura),
          ),
        };
      },
    );
  }
}
