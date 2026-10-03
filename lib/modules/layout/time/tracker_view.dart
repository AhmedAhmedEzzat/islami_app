import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/services/prayer_tracker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/prayer_labels.dart';

/// Log each of the five prayers as you pray it, with a streak and the week
/// at a glance.
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
        ],
      ),
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
