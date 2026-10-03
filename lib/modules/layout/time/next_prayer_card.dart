import 'package:flutter/material.dart';
// intl also exports TextDirection, which shadows the Flutter one.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/services/prayer_times_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/prayer_labels.dart';

/// "01:02:03" — hours are not wrapped, so a gap over a day still reads right.
String formatCountdown(Duration d) {
  if (d.isNegative) return '00:00:00';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

/// The next prayer, its time, a live countdown and progress since the last one.
class NextPrayerCard extends StatelessWidget {
  const NextPrayerCard({
    super.key,
    required this.result,
    required this.now,
    this.subtitle,
    this.onTap,
  });

  final PrayerTimesResult result;
  final DateTime now;

  /// Shown under the label, e.g. the place the times are for.
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final next = result.next!;
    final locale = Localizations.localeOf(context).toLanguageTag();

    // Progress through the gap between the previous prayer and the next one.
    final before = result.prayers.lastWhere(
      (p) => !p.time.isAfter(now),
      orElse: () => result.prayers.first,
    );
    final span = next.time.difference(before.time).inSeconds;
    final done = now.difference(before.time).inSeconds;
    final progress = span <= 0 ? 0.0 : (done / span).clamp(0.0, 1.0);

    return Card(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                subtitle == null
                    ? context.l10n.nextPrayer
                    : '${context.l10n.nextPrayer} · $subtitle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Long names at large font scales shrink rather than clip.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.bottomStart,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            prayerLabel(context, next.prayer),
                            style: context.texts.headlineMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            DateFormat.jm(locale).format(next.time),
                            style: context.texts.titleMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    formatCountdown(next.time.difference(now)),
                    // Latin digits keep the countdown steady as it ticks.
                    textDirection: TextDirection.ltr,
                    style: context.texts.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: AppRadius.pillRadius,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: scheme.onPrimaryContainer.withValues(
                    alpha: 0.15,
                  ),
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
