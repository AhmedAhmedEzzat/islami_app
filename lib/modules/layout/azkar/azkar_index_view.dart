import 'package:flutter/material.dart';

import '../../../core/services/azkar_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../models/zikr_model.dart';
import 'azkar_labels.dart';
import 'azkar_view.dart';

/// Every chapter of Hisn al-Muslim: the daily ones up front, the rest
/// searchable below.
class AzkarIndexView extends StatefulWidget {
  const AzkarIndexView({super.key, this.embedded = false});

  /// True when shown inside a tab, where the tab supplies the page chrome.
  final bool embedded;

  @override
  State<AzkarIndexView> createState() => _AzkarIndexViewState();
}

class _AzkarIndexViewState extends State<AzkarIndexView> {
  late final Future<List<AzkarChapter>> _chapters = AzkarService.loadAll();
  String _query = '';

  void _open(AzkarChapter c) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => AzkarView(chapterId: c.id)),
  );

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<List<AzkarChapter>>(
      future: _chapters,
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) return const Center(child: CircularProgressIndicator());
        return _content(all);
      },
    );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: Text(context.l10n.hisnTitle)), body: body);
  }

  Widget _content(List<AzkarChapter> all) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final byId = {for (final c in all) c.id: c};
    final featured = [for (final id in FeaturedAzkar.all) ?byId[id]];

    final q = ArabicText.normalizeForSearch(_query);
    final filtered = q.isEmpty
        ? all
        : all.where((c) {
            return ArabicText.normalizeForSearch(c.title).contains(q) ||
                azkarTitle(context, c).toLowerCase().contains(_query.toLowerCase()) ||
                c.items.any((z) => ArabicText.normalizeForSearch(z.text).contains(q));
          }).toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: SearchBar(
              hintText: l10n.searchAzkarHint,
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        if (q.isEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: Text(l10n.featuredAzkar, style: context.texts.titleMedium),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.4,
              children: [
                for (final c in featured)
                  Card(
                    color: scheme.secondaryContainer,
                    child: InkWell(
                      borderRadius: AppRadius.cardRadius,
                      onTap: () => _open(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(azkarIcon(c.id), color: scheme.onSecondaryContainer),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                azkarTitle(context, c),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.labelLarge?.copyWith(
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: Text(l10n.allChapters, style: context.texts.titleMedium),
            ),
          ),
        ],
        SliverList.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, i) {
            final c = filtered[i];
            return ListTile(
              title: Text(c.title, textDirection: TextDirection.rtl),
              trailing: Text(
                '${c.items.length}',
                style: context.texts.labelMedium?.copyWith(color: scheme.primary),
              ),
              onTap: () => _open(c),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}
