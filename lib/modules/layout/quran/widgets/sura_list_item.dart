import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/services/quran_meta.dart';
import '../../../../models/sura_data_model.dart';
import '../../../../core/utils/l10n_ext.dart';

class SuraListItem extends StatelessWidget {
  const SuraListItem({super.key, required this.suraDataModel, this.onSurahTap});

  final SuraDataModel suraDataModel;
  final VoidCallback? onSurahTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    // ListTile (rather than the old GestureDetector around a Row with a
    // Spacer) gives a full-width hit target and a ripple. Taps landing in the
    // gap between the English and Arabic names used to be swallowed.
    return ListTile(
      onTap: onSurahTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          suraDataModel.suraID,
          style: context.texts.labelLarge?.copyWith(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        context.isArabic ? suraDataModel.suraNameAR : suraDataModel.suraNameEN,
        style: context.texts.titleMedium?.copyWith(color: scheme.onSurface),
      ),
      subtitle: Text(
        _subtitle(context),
        style: context.texts.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        context.isArabic ? suraDataModel.suraNameEN : suraDataModel.suraNameAR,
        style: context.texts.titleMedium?.copyWith(color: scheme.primary),
      ),
    );
  }

  /// "Meccan · 7 verses".
  String _subtitle(BuildContext context) {
    final count = context.l10n.verseCount(
      int.tryParse(suraDataModel.suraVersesNumber) ?? 0,
    );
    final info = QuranMeta.instance?.sura(int.parse(suraDataModel.suraID));
    if (info == null) return count;
    final place = info.isMeccan ? context.l10n.meccan : context.l10n.medinan;
    return '$place · $count';
  }
}
