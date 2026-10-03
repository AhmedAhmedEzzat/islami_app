import 'package:flutter/material.dart';

import '../../../../models/sura_data_model.dart';
import 'sura_list_item.dart';

/// The sura list as a sliver.
///
/// It used to be a shrink-wrapped, non-scrolling ListView inside a
/// SingleChildScrollView, which built all 114 rows on every frame. As a sliver
/// inside the page's own CustomScrollView it is virtualised again.
class SuraListSliver extends StatelessWidget {
  const SuraListSliver({
    super.key,
    required this.onSurahTap,
    required this.suraDataModels,
  });

  final void Function(int) onSurahTap;
  final List<SuraDataModel> suraDataModels;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: suraDataModels.length,
      // Divider.indent is not direction-aware: it is always the left edge,
      // while ListTile.leading flips to the right under RTL.
      separatorBuilder: (context, _) {
        final rtl = Directionality.of(context) == TextDirection.rtl;
        return Divider(indent: rtl ? 16 : 72, endIndent: rtl ? 72 : 16);
      },
      itemBuilder: (context, index) {
        final sura = suraDataModels[index];
        return SuraListItem(
          suraDataModel: sura,
          onSurahTap: () => onSurahTap(int.parse(sura.suraID) - 1),
        );
      },
    );
  }
}
