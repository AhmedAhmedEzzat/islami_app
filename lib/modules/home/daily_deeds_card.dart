import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/daily_deeds.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/text_prompt_dialog.dart';
import '../more/listen_view.dart' show confirmDelete;

/// Today's good deeds, ticked off as they are done, with the run of days on
/// which all of them were.
class DailyDeedsCard extends StatelessWidget {
  const DailyDeedsCard({super.key, required this.now});

  final DateTime now;

  static String deedTitle(BuildContext context, Deed d) {
    if (!d.builtIn) return d.title;
    final l10n = context.l10n;
    return switch (d.id) {
      'morningAdhkar' => l10n.deedMorningAdhkar,
      'eveningAdhkar' => l10n.deedEveningAdhkar,
      'quran' => l10n.deedQuran,
      'sunnah' => l10n.deedSunnah,
      'witr' => l10n.deedWitr,
      'sadaqa' => l10n.deedSadaqa,
      _ => d.id,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final today = DateTime(now.year, now.month, now.day);
    return ValueListenableBuilder<int>(
      valueListenable: DailyDeeds.changes,
      builder: (context, _, _) {
        final deeds = DailyDeeds.visible();
        final done = DailyDeeds.doneOn(today);
        final count = deeds.where((d) => done.contains(d.id)).length;
        final streak = DailyDeeds.streak(today);
        return Card(
          color: scheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.lg, AppSpacing.sm, AppSpacing.xs, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.task_alt, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.deedsTitle, style: context.texts.titleMedium),
                          Text(
                            [
                              l10n.deedsProgress(count, deeds.length),
                              if (streak > 0) l10n.deedsStreak(streak),
                            ].join(' · '),
                            style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.deedsEdit,
                      icon: const Icon(Icons.tune),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        isScrollControlled: true,
                        builder: (_) => const _EditDeedsSheet(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final d in deeds)
                        FilterChip(
                          label: Text(deedTitle(context, d)),
                          selected: done.contains(d.id),
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            DailyDeeds.toggle(today, d.id);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Which deeds are on the list, and the reader's own.
class _EditDeedsSheet extends StatelessWidget {
  const _EditDeedsSheet();

  Future<void> _add(BuildContext context) async {
    final l10n = context.l10n;
    final text = await showTextPrompt(
      context,
      title: l10n.deedsAdd,
      confirm: l10n.deedsAddConfirm,
      hint: l10n.deedsAddHint,
      maxLength: 60,
    );
    if (text != null) await DailyDeeds.addCustom(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<int>(
      valueListenable: DailyDeeds.changes,
      builder: (context, _, _) {
        final hidden = DailyDeeds.hidden();
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: AppSpacing.pageH,
                  child: Text(l10n.deedsEdit, style: context.texts.titleMedium),
                ),
                for (final d in DailyDeeds.all())
                  // A plain tile, so the switch and the delete button stay two
                  // controls for a screen reader too.
                  ListTile(
                    title: Text(DailyDeedsCard.deedTitle(context, d)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!d.builtIn)
                          IconButton(
                            tooltip: l10n.delete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final name = DailyDeedsCard.deedTitle(context, d);
                              if (await confirmDelete(context, l10n.deedsDeleteConfirm(name))) {
                                await DailyDeeds.removeCustom(d.id);
                              }
                            },
                          ),
                        Switch(
                          value: !hidden.contains(d.id),
                          onChanged: (on) => DailyDeeds.setShown(d.id, on),
                        ),
                      ],
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(l10n.deedsAdd),
                  onTap: () => _add(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
