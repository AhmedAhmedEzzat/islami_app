import 'package:flutter/material.dart';

import '../../../core/constants/assets.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/app_background.dart';
import '../tasbeh/tasbeh_view.dart';
import 'azkar_index_view.dart';

/// Hisn al-Muslim and the tasbeh counter, side by side.
class AzkarTabView extends StatelessWidget {
  const AzkarTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBackground(
      ornament: Assets.tasbehBackground,
      title: l10n.tabAzkar,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(tabs: [Tab(text: l10n.hisnTitle), Tab(text: l10n.tasbehTitle)]),
            const Expanded(
              child: TabBarView(
                children: [
                  AzkarIndexView(embedded: true),
                  TasbehView(embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
