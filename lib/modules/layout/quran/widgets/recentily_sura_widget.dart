import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/sura_data_model.dart';
import 'recently_item_widget.dart';
import '../../../../core/utils/l10n_ext.dart';

class RecentlySuraWidget extends StatelessWidget {
  const RecentlySuraWidget({
    super.key,
    required this.suraDataModel,
    required this.onOpen,
  });

  final List<SuraDataModel> suraDataModel;
  final void Function(SuraDataModel sura) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            context.l10n.continueReading,
            style: context.texts.titleMedium?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            // Horizontal lists are not direction-aware on their own.
            reverse: Directionality.of(context) == TextDirection.rtl,
            itemCount: suraDataModel.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final sura = suraDataModel[index];
              return InkWell(
                borderRadius: AppRadius.cardRadius,
                onTap: () => onOpen(sura),
                child: RecentlyItemWidget(suraDataModel: sura),
              );
            },
          ),
        ),
      ],
    );
  }
}
