import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/sura_data_model.dart';
import 'mushaf_page.dart';
import '../../../../core/utils/l10n_ext.dart';

class RecentlyItemWidget extends StatelessWidget {
  const RecentlyItemWidget({super.key, required this.suraDataModel});

  final SuraDataModel suraDataModel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: scheme.onPrimaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.isArabic
                      ? suraDataModel.suraNameAR
                      : suraDataModel.suraNameEN,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          Text(
            context.isArabic
                ? suraDataModel.suraNameEN
                : suraDataModel.suraNameAR,
            style: context.texts.headlineSmall?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
          Text(
            // Where the reader stopped, if they got past the first page.
            MushafPage.savedPosition(suraDataModel.suraID) > 0
                ? context.l10n.verseNumber(
                    MushafPage.savedPosition(suraDataModel.suraID) + 1,
                  )
                : context.l10n.verseCount(
                    int.tryParse(suraDataModel.suraVersesNumber) ?? 0,
                  ),
            style: context.texts.bodySmall?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
