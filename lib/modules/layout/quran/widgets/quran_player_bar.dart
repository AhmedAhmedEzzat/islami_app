import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/reciters.dart';
import '../../../../core/services/recitation_downloads.dart';
import '../../../../core/state/quran_player_cubit.dart';
import '../../../../core/state/quran_player_state.dart';
import '../../../../core/state/settings_cubit.dart';
import '../../../../core/state/settings_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/l10n_ext.dart';
import '../../../../core/utils/on_screen.dart';
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
        // Only the screen in view says so; another may be listening too.
        if (isOnScreen(context)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.recitationOffline)),
          );
        }
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
        } else if (state.range case final r?) {
          status = context.l10n.rangeStatus(state.ayah ?? r.from, r.from, r.to, r.passes);
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
                    _MoreMenu(reciter: reciter, model: sura),
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

enum _MenuAction { sleep, continuous, verseRepeat, range, download }

/// Sleep timer, continuous play and this sura's download, which do not need
/// a button each on the bar.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.reciter, required this.model});

  final Reciter reciter;
  final SuraDataModel model;

  int get sura => int.parse(model.suraID);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = context.read<SettingsCubit>();
    final player = context.read<QuranPlayerCubit>();
    final looping = player.state.isLoaded(model.suraID) && player.state.range != null;
    return ValueListenableBuilder<int>(
      valueListenable: RecitationDownloads.changes,
      builder: (context, _, _) {
        final downloaded = RecitationDownloads.isDownloaded(reciter.id, sura);
        final job = RecitationDownloads.jobFor(reciter.id, sura);
        final busy = job != null && job.status != DownloadStatus.failed;
        // Actions run from onSelected, after the menu has closed: an item's
        // onTap runs before the menu pops itself, which would close a sheet
        // opened from it straight away.
        return PopupMenuButton<_MenuAction>(
          tooltip: l10n.moreOptions,
          onSelected: (action) {
            switch (action) {
              case _MenuAction.sleep:
                // A repeated verse never reaches the end of the sura.
                showSleepTimerSheet(
                  context,
                  offerEndOfSura: context.read<QuranPlayerCubit>().state.repeat != RecitationRepeat.verse,
                );
              case _MenuAction.continuous:
                settings.setContinuousRecitation(!settings.state.continuousRecitation);
              case _MenuAction.verseRepeat:
                _pickVerseRepeat(context);
              case _MenuAction.range:
                looping ? player.clearRange() : _pickRange(context);
              case _MenuAction.download:
                if (downloaded) {
                  RecitationDownloads.delete(reciter, sura);
                } else if (busy) {
                  RecitationDownloads.cancel(reciter.id);
                } else {
                  RecitationDownloads.download(reciter, sura);
                }
            }
          },
          // A ring on the menu button while this sura downloads.
          icon: busy
              ? SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(value: job.progress, strokeWidth: 2.5),
                )
              : const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _MenuAction.sleep,
              child: ListTile(leading: const Icon(Icons.bedtime_outlined), title: Text(l10n.sleepTimer)),
            ),
            CheckedPopupMenuItem(
              value: _MenuAction.continuous,
              checked: settings.state.continuousRecitation,
              child: Text(l10n.continuousRecitation),
            ),
            PopupMenuItem(
              value: _MenuAction.verseRepeat,
              child: ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text(l10n.verseRepeat),
                subtitle: Text(l10n.verseRepeatTimes(settings.state.verseRepeat)),
              ),
            ),
            PopupMenuItem(
              value: _MenuAction.range,
              child: ListTile(
                leading: Icon(looping ? Icons.stop_circle_outlined : Icons.loop),
                title: Text(looping ? l10n.stopRange : l10n.repeatRange),
              ),
            ),
            if (RecitationDownloads.supported)
              PopupMenuItem(
                value: _MenuAction.download,
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

  /// A passage of this sura, several times over, for memorising it.
  Future<void> _pickRange(BuildContext context) async {
    final player = context.read<QuranPlayerCubit>();
    final total = int.parse(model.suraVersesNumber);
    final current = player.state.isLoaded(model.suraID) ? (player.state.ayah ?? 1).clamp(1, total) : 1;
    final range = await showDialog<VerseRange>(
      context: context,
      builder: (_) => _RangeDialog(total: total, initialFrom: current),
    );
    if (range == null || !context.mounted) return;
    await player.playFrom(
      suraId: model.suraID,
      fromAyah: range.from,
      totalAyahs: total,
      reciterId: reciter.id,
      range: range,
    );
  }

  /// Each verse several times before the next, for memorising. A change
  /// applies at once, from the verse playing.
  static Future<void> _pickVerseRepeat(BuildContext context) async {
    final settings = context.read<SettingsCubit>();
    final player = context.read<QuranPlayerCubit>();
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.verseRepeat),
        children: [
          for (final n in SettingsState.verseRepeatChoices)
            ListTile(
              title: Text(context.l10n.verseRepeatTimes(n)),
              trailing: n == settings.state.verseRepeat ? Icon(Icons.check, color: context.colors.primary) : null,
              onTap: () => Navigator.pop(context, n),
            ),
        ],
      ),
    );
    if (picked == null || picked == settings.state.verseRepeat) return;
    await settings.setVerseRepeat(picked);
    // Applies at once whether playing or paused.
    if (player.state.suraId != null) await player.restartFromCurrentVerse();
  }
}

/// Chooses the passage and how many times to recite it.
class _RangeDialog extends StatefulWidget {
  const _RangeDialog({required this.total, required this.initialFrom});

  final int total;
  final int initialFrom;

  static const List<int> passChoices = [2, 3, 5, 7, 10, 20];

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late int _from = widget.initialFrom;
  late int _to = (widget.initialFrom + 4).clamp(1, widget.total);
  int _passes = 3;

  Widget _verses(String label, int value, int min, ValueChanged<int> onChanged) => DropdownButtonFormField<int>(
    initialValue: value,
    isExpanded: true,
    menuMaxHeight: 320,
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    items: [
      for (var a = min; a <= widget.total; a++) DropdownMenuItem(value: a, child: Text('$a')),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.repeatRangeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _verses(l10n.fromVerse, _from, 1, (v) => setState(() {
                  _from = v;
                  if (_to < v) _to = v;
                })),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                // Keyed on the start, so its list always begins there.
                child: KeyedSubtree(
                  key: ValueKey(_from),
                  child: _verses(l10n.toVerse, _to, _from, (v) => setState(() => _to = v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.rangePasses, style: context.texts.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final n in _RangeDialog.passChoices)
                ChoiceChip(
                  label: Text(l10n.rangeTimes(n)),
                  selected: _passes == n,
                  onSelected: (_) => setState(() => _passes = n),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, VerseRange(_from, _to, _passes)),
          child: Text(l10n.startRange),
        ),
      ],
    );
  }
}
