import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';
import '../../core/services/hifz.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';
import '../layout/quran/quran_view.dart';

/// Memorisation: how much of the Quran is known by heart, what is due for
/// revision today, and where every sura stands.
class HifzView extends StatefulWidget {
  const HifzView({super.key});

  @override
  State<HifzView> createState() => _HifzViewState();
}

enum _Filter { all, memorised, learning, notStarted }

class _HifzViewState extends State<HifzView> {
  _Filter _filter = _Filter.all;

  Future<void> _choose(int sura) async {
    final l10n = context.l10n;
    final current = Hifz.of(sura)?.status;
    final picked = await showModalBottomSheet<(bool, HifzStatus?)>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(suraName(context, sura), style: context.texts.titleMedium),
            ),
            for (final (status, label, icon) in [
              (null, l10n.hifzNotStarted, Icons.radio_button_unchecked),
              (HifzStatus.learning, l10n.hifzLearning, Icons.timelapse),
              (HifzStatus.memorised, l10n.hifzMemorised, Icons.check_circle),
            ])
              ListTile(
                leading: Icon(icon, color: _statusColor(context, status)),
                title: Text(label),
                trailing: status == current ? Icon(Icons.check, color: context.colors.primary) : null,
                onTap: () => Navigator.pop(context, (true, status)),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(l10n.openSura),
              onTap: () => Navigator.pop(context, (false, null)),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final (setIt, status) = picked;
    if (setIt) {
      await Hifz.setStatus(sura, status);
    } else {
      await openSura(context, suraByNumber(sura));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hifzTitle)),
      body: ValueListenableBuilder<int>(
        valueListenable: Hifz.changes,
        builder: (context, _, _) {
          final all = Hifz.all();
          final now = DateTime.now();
          final due = Hifz.dueBy(now);
          final verses = Hifz.memorisedVerses();
          final suras = [
            for (var s = 1; s <= Constants.suraDataLists.length; s++)
              if (switch (_filter) {
                _Filter.all => true,
                _Filter.memorised => all[s]?.status == HifzStatus.memorised,
                _Filter.learning => all[s]?.status == HifzStatus.learning,
                _Filter.notStarted => all[s] == null,
              })
                s,
          ];

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    color: scheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.hifzPercent((verses * 100 / 6236).toStringAsFixed(verses == 0 || verses >= 6236 ? 0 : 1)),
                            style: context.texts.headlineSmall?.copyWith(color: scheme.onPrimaryContainer),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: LinearProgressIndicator(
                              value: verses / 6236,
                              minHeight: 8,
                              backgroundColor: scheme.onPrimaryContainer.withValues(alpha: 0.12),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.hifzSummary(Hifz.count(HifzStatus.memorised), Hifz.count(HifzStatus.learning), verses),
                            style: context.texts.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (all.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
                    child: Text(
                      l10n.hifzIntro,
                      style: context.texts.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              if (due.isNotEmpty) ...[
                _Header(l10n.hifzDueToday(due.length)),
                SliverList.builder(
                  itemCount: due.length,
                  itemBuilder: (context, i) => _DueTile(sura: due[i], entry: all[due[i]]!, today: now),
                ),
              ],
              _Header(l10n.hifzAllSuras),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: [
                      for (final (f, label) in [
                        (_Filter.all, l10n.hifzFilterAll),
                        (_Filter.memorised, l10n.hifzMemorised),
                        (_Filter.learning, l10n.hifzLearning),
                        (_Filter.notStarted, l10n.hifzNotStarted),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                sliver: SliverList.builder(
                  itemCount: suras.length,
                  itemBuilder: (context, i) {
                    final s = suras[i];
                    final entry = all[s];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.secondaryContainer,
                        child: Text('$s', style: context.texts.labelMedium),
                      ),
                      title: Text(suraName(context, s)),
                      subtitle: Text(_statusLabel(context, entry)),
                      trailing: Icon(
                        switch (entry?.status) {
                          HifzStatus.memorised => Icons.check_circle,
                          HifzStatus.learning => Icons.timelapse,
                          null => Icons.radio_button_unchecked,
                        },
                        color: _statusColor(context, entry?.status),
                      ),
                      onTap: () => _choose(s),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _statusLabel(BuildContext context, HifzEntry? entry) {
    final l10n = context.l10n;
    return switch (entry?.status) {
      null => l10n.hifzNotStarted,
      HifzStatus.learning => l10n.hifzLearning,
      HifzStatus.memorised when entry!.due?.isAfter(DateUtils.dateOnly(DateTime.now())) ?? false =>
        l10n.hifzNextRevision(MaterialLocalizations.of(context).formatMediumDate(entry.due!)),
      HifzStatus.memorised => l10n.hifzRevisionDue,
    };
  }
}

Color _statusColor(BuildContext context, HifzStatus? status) => switch (status) {
  HifzStatus.memorised => context.colors.primary,
  HifzStatus.learning => context.colors.tertiary,
  null => context.colors.outline,
};

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
    sliver: SliverToBoxAdapter(
      child: Text(text, style: context.texts.titleSmall?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w700)),
    ),
  );
}

/// A sura due for revision, with the two ways a revision can go.
class _DueTile extends StatelessWidget {
  const _DueTile({required this.sura, required this.entry, required this.today});

  final int sura;
  final HifzEntry entry;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final due = entry.due!;
    final late = DateTime.utc(today.year, today.month, today.day).difference(DateTime.utc(due.year, due.month, due.day)).inDays;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      color: context.colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => openSura(context, suraByNumber(sura)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(suraName(context, sura), style: context.texts.titleMedium),
                    Text(
                      late > 0 ? l10n.hifzOverdue(late) : l10n.hifzDueNow,
                      style: context.texts.bodySmall?.copyWith(
                        color: late > 0 ? context.colors.error : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => Hifz.revised(sura, easy: false),
              child: Text(l10n.hifzHard),
            ),
            FilledButton.tonal(
              onPressed: () => Hifz.revised(sura, easy: true),
              child: Text(l10n.hifzRevised),
            ),
          ],
        ),
      ),
    );
  }
}
