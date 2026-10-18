import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/services/prayer_tracker.dart';
import '../../../core/services/qada.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/prayer_labels.dart';

/// Log each of the five prayers as you pray it, with a streak and the week
/// at a glance, and count the missed prayers still to make up.
class TrackerView extends StatefulWidget {
  const TrackerView({super.key});

  @override
  State<TrackerView> createState() => _TrackerViewState();
}

class _TrackerViewState extends State<TrackerView> {
  DateTime _selected = DateUtils.dateOnly(DateTime.now());

  Future<void> _toggle(prayer) async {
    HapticFeedback.selectionClick();
    await PrayerTracker.toggle(_selected, prayer);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final today = DateUtils.dateOnly(DateTime.now());
    final locale = Localizations.localeOf(context).toLanguageTag();
    // The last seven days, oldest first.
    final week = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.prayerTracker)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.local_fire_department_outlined,
                  label: l10n.trackerStreak(PrayerTracker.streak(today)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Stat(
                  icon: Icons.insights_outlined,
                  label: l10n.trackerMonth(PrayerTracker.monthPercent(today)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.trackerThisWeek, style: context.texts.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final day in week)
                Expanded(
                  child: InkWell(
                    borderRadius: AppRadius.cardRadius,
                    onTap: () => setState(() => _selected = day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.cardRadius,
                        color: day == _selected ? scheme.secondaryContainer : null,
                      ),
                      child: Column(
                        children: [
                          Text(DateFormat.E(locale).format(day), style: context.texts.labelSmall),
                          const SizedBox(height: AppSpacing.xs),
                          for (final p in PrayerTracker.prayers)
                            Container(
                              margin: const EdgeInsets.all(1.5),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: PrayerTracker.isDone(day, p)
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            _selected == today
                ? l10n.trackerToday
                : DateFormat.yMMMMEEEEd(locale).format(_selected),
            style: context.texts.titleMedium,
          ),
          Text(
            l10n.trackerHint,
            style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            color: scheme.surfaceContainerLow,
            child: Column(
              children: [
                for (final p in PrayerTracker.prayers)
                  CheckboxListTile(
                    value: PrayerTracker.isDone(_selected, p),
                    onChanged: (_) => _toggle(p),
                    title: Text(prayerLabel(context, p)),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _QadaSection(
            onChanged: () {
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

/// Missed prayers to make up: a count per prayer, made up one at a time.
class _QadaSection extends StatelessWidget {
  const _QadaSection({required this.onChanged});

  final VoidCallback onChanged;

  Future<void> _addDays(BuildContext context) async {
    final controller = TextEditingController();
    final days = await showDialog<int>(
      context: context,
      builder: (context) {
        void submit() => Navigator.pop(context, int.tryParse(controller.text));
        return AlertDialog(
          title: Text(context.l10n.qadaAddDays),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.qadaAddDaysHint),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                decoration: InputDecoration(labelText: context.l10n.qadaDays, border: const OutlineInputBorder()),
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(onPressed: submit, child: Text(context.l10n.qadaAdd)),
          ],
        );
      },
    );
    controller.dispose();
    if (days == null || days <= 0) return;
    await Qada.addDays(days);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final total = Qada.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.qadaTitle, style: context.texts.titleMedium)),
            TextButton.icon(
              onPressed: () => _addDays(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.qadaAddDays),
            ),
          ],
        ),
        Text(
          total == 0 ? l10n.qadaNone : l10n.qadaTotal(total),
          style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          color: scheme.surfaceContainerLow,
          child: Column(
            children: [
              for (final p in PrayerTracker.prayers)
                ListTile(
                  title: Text(prayerLabel(context, p)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.qadaMadeUp,
                        onPressed: Qada.count(p) == 0
                            ? null
                            : () async {
                                HapticFeedback.selectionClick();
                                await Qada.add(p, -1);
                                onChanged();
                              },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${Qada.count(p)}',
                          textAlign: TextAlign.center,
                          style: context.texts.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.qadaMissed,
                        onPressed: () async {
                          HapticFeedback.selectionClick();
                          await Qada.add(p, 1);
                          onChanged();
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(icon, color: context.colors.onPrimaryContainer),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.texts.titleSmall?.copyWith(color: context.colors.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}
