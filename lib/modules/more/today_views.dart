import 'package:material_ui/material_ui.dart';

import '../../core/constants/constants.dart';
import '../../core/services/mushaf_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';
import '../home/daily_deeds_card.dart';
import '../home/khatma_card.dart';
import '../layout/layout_scope.dart';
import '../layout/quran/quran_view.dart';

/// The khatma on a page of its own, reached from More. Home shows it too
/// while one is under way.
class KhatmaView extends StatelessWidget {
  const KhatmaView({super.key});

  Future<void> _openPage(BuildContext context, int page) async {
    final layout = await MushafLayout.load();
    if (!context.mounted) return;
    final p = page.clamp(1, MushafLayout.pageCount);
    final sura = Constants.suraDataLists[layout.firstWord(p).sura - 1];
    final scope = LayoutScope.maybeOf(context);
    if (scope != null) {
      scope.openSura(sura, page: p);
    } else {
      openSura(context, sura, page: p);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.khatmaTitle)),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        KhatmaCard(
          now: DateTime.now(),
          onOpenPage: (p) => _openPage(context, p),
        ),
      ],
    ),
  );
}

/// Today's good deeds, reached from More.
class DailyDeedsView extends StatelessWidget {
  const DailyDeedsView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.deedsTitle)),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [DailyDeedsCard(now: DateTime.now())],
    ),
  );
}
