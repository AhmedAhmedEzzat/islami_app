import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../models/zikr_model.dart';
import '../azkar/azkar_index_view.dart';
import '../azkar/azkar_view.dart';

/// Shortcuts to the adhkar people reach for around the prayers.
class AzkarSection extends StatelessWidget {
  const AzkarSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Card(
                icon: Icons.wb_twilight,
                label: l10n.azkarMorningEvening,
                chapterId: FeaturedAzkar.morningEvening,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Card(
                icon: Icons.mosque_outlined,
                label: l10n.azkarAfterPrayer,
                chapterId: FeaturedAzkar.afterPrayer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Card(
                icon: Icons.bedtime_outlined,
                label: l10n.azkarSleep,
                chapterId: FeaturedAzkar.sleep,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AzkarIndexView()),
            ),
            icon: const Icon(Icons.auto_stories_outlined),
            label: Text(l10n.hisnTitle),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.label, required this.chapterId});

  final IconData icon;
  final String label;
  final int chapterId;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Card(
      color: scheme.secondaryContainer,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => AzkarView(chapterId: chapterId)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
          child: Column(
            children: [
              Icon(icon, color: scheme.onSecondaryContainer),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: context.texts.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
