import 'package:flutter/material.dart';

import '../../core/services/khatma.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';

/// The reader's khatma on the Home screen: today's portion and overall
/// progress, or an invitation to start one.
class KhatmaCard extends StatelessWidget {
  const KhatmaCard({super.key, required this.now, required this.onOpenPage});

  final DateTime now;

  /// Opens the mushaf at a 1-based page.
  final ValueChanged<int> onOpenPage;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KhatmaPlan?>(
      valueListenable: Khatma.notifier,
      builder: (context, plan, _) {
        if (plan == null) return _Invite(onStart: () => showStartSheet(context));
        return plan.isComplete
            ? _Complete(onRestart: () => showStartSheet(context))
            : _Progress(plan: plan, now: now, onOpenPage: onOpenPage);
      },
    );
  }

  /// Asks how many days to finish in, and starts the plan.
  static Future<void> showStartSheet(BuildContext context) async {
    final days = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _StartSheet(),
    );
    if (days != null) await Khatma.start(days);
  }
}

class _Invite extends StatelessWidget {
  const _Invite({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: context.colors.surfaceContainer,
      child: ListTile(
        leading: Icon(Icons.flag_outlined, color: context.colors.primary),
        title: Text(l10n.khatmaStart),
        subtitle: Text(l10n.khatmaStartSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onStart,
      ),
    );
  }
}

class _Complete extends StatelessWidget {
  const _Complete({required this.onRestart});

  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration_outlined, color: scheme.onPrimaryContainer),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.khatmaComplete,
                    style: context.texts.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.khatmaCompleteBody, style: context.texts.bodyMedium?.copyWith(color: scheme.onPrimaryContainer)),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                FilledButton(onPressed: onRestart, child: Text(l10n.khatmaStartAgain)),
                const SizedBox(width: AppSpacing.sm),
                TextButton(onPressed: Khatma.stop, child: Text(l10n.khatmaDismiss)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.plan, required this.now, required this.onOpenPage});

  final KhatmaPlan plan;
  final DateTime now;
  final ValueChanged<int> onOpenPage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final today = plan.today(now);
    final left = plan.pagesLeftToday(now);

    return Card(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.lg, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_outlined, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.khatmaTitle, style: context.texts.titleMedium)),
                Text(
                  l10n.khatmaDayOf(plan.dayIndex(now) + 1, plan.days),
                  style: context.texts.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                PopupMenuButton<void>(
                  tooltip: l10n.moreOptions,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: () => KhatmaCard.showStartSheet(context),
                      child: Text(l10n.khatmaChangePlan),
                    ),
                    PopupMenuItem(onTap: Khatma.stop, child: Text(l10n.khatmaEnd)),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(value: plan.progress, minHeight: 8),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.khatmaProgress(plan.furthest, KhatmaPlan.pages, (plan.progress * 100).floor()),
                    style: context.texts.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          left == 0 ? l10n.khatmaTodayDone : l10n.khatmaToday(today.from, today.to, left),
                          style: context.texts.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        onPressed: () => onOpenPage(plan.furthest + 1),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(left == 0 ? l10n.khatmaReadAhead : l10n.khatmaRead),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartSheet extends StatefulWidget {
  const _StartSheet();

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final perDay = (KhatmaPlan.pages / _days).ceil();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.khatmaStart, style: context.texts.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.khatmaFinishIn, style: context.texts.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final d in KhatmaPlan.dayChoices)
                  ChoiceChip(
                    label: Text(l10n.daysCount(d)),
                    selected: d == _days,
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.khatmaPerDay(perDay), style: context.texts.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context, _days), child: Text(l10n.khatmaBegin)),
            ),
          ],
        ),
      ),
    );
  }
}
